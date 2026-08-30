// End-to-end proof that the Debtors feature actually works through the REAL
// data layer (real SQLite via sqflite_common_ffi, real repositories, real
// AuthRepository.login, real RecoveryProvider.createDebtor / createCase, real
// audit logging + cross-client enforcement + repository-level masking).
//
// It runs headless with `flutter test` — no GUI interaction required — because
// it exercises the same provider/repository methods the UI screens call.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:recovera_crm/database/database_helper.dart';
import 'package:recovera_crm/repositories/audit_repository.dart';
import 'package:recovera_crm/repositories/auth_repository.dart';
import 'package:recovera_crm/repositories/contact_repository.dart';
import 'package:recovera_crm/repositories/case_repository.dart';
import 'package:recovera_crm/repositories/crm_activity_repository.dart';
import 'package:recovera_crm/repositories/debtor_repository.dart';
import 'package:recovera_crm/repositories/lead_repository.dart';
import 'package:recovera_crm/repositories/organization_repository.dart';
import 'package:recovera_crm/repositories/user_repository.dart';
import 'package:recovera_crm/providers/recovery_provider.dart';
import 'package:recovera_crm/providers/crm_provider.dart';
import 'package:recovera_crm/models/auth_session.dart';
import 'package:recovera_crm/models/case_model.dart';
import 'package:recovera_crm/models/debtor_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  // Use the FFI (no platform channels) so this runs in the plain test VM.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Creating a debtor then a case links them in the real DB', () async {
    final dir = Directory.systemTemp.createTempSync('recovera_test_');
    addTearDown(() async {
      await dir.delete(recursive: true);
    });

    final dbHelper = DatabaseHelper.withPath(dir.path);
    final db = await dbHelper.database;

    final auditRepo = AuditRepository(dbHelper);
    final userRepo = UserRepository(dbHelper, auditRepo);
    final orgRepo = OrganizationRepository(dbHelper, auditRepo);
    final contactRepo = ContactRepository(dbHelper, auditRepo);
    final leadRepo = LeadRepository(dbHelper, auditRepo);
    final crmActivityRepo = CrmActivityRepository(dbHelper);
    final debtorRepo = DebtorRepository(dbHelper);
    final caseRepo = CaseRepository(dbHelper);

    final authRepo = AuthRepository(
      userRepo,
      auditRepo,
      additionalRepos: [
        orgRepo,
        contactRepo,
        leadRepo,
        crmActivityRepo,
        debtorRepo,
        caseRepo,
      ],
    );

    // ── 1. Real login as the seeded super-admin ──────────────────────────
    final session = await authRepo.login('admin', 'Admin@1234');
    expect(session.username, 'admin');
    expect(session.isSuperAdmin, isTrue);
    // Sessions must have propagated to EVERY repository (incl. debtor/case).
    expect(debtorRepo.currentSession.username, 'admin');
    expect(caseRepo.currentSession.userId, session.userId);

    final recProv = RecoveryProvider(caseRepo, debtorRepo);
    final crmProv = CrmProvider(
      orgRepo,
      contactRepo,
      leadRepo,
      crmActivityRepo,
    );

    // ── 2. Load cross-references + seed sanity ───────────────────────────
    await crmProv.loadOrganizations();
    await recProv.loadDebtors();
    await recProv.loadCaseCounts();

    final orgs = crmProv.organizations;
    final org1 = orgs.firstWhere((o) => o.companyName == 'Telco One Rwanda');
    final org2 = orgs.firstWhere((o) => o.companyName == 'Metro Insurance Ltd');

    final seededDebtor = recProv.debtors.firstWhere(
      (d) => d.name == 'Acme Trading Corp',
    );
    // Super admin has `debtor.sensitive`, so sensitive fields are NOT masked.
    expect(seededDebtor.clientId, org1.id);
    expect(seededDebtor.phone, '+250 788 999 999');

    // ── 3. Replicate the Debtors screen "New Debtor" → RecoveryProvider ───
    final newDebtor = DebtorModel(
      id: const Uuid().v4(),
      clientId: org1.id,
      name: 'Kigali Coffee Traders',
      type: 'Company',
      phone: '+250 788 333 444',
      email: 'accounts@kigalicoffee.rw',
      address: 'KG 8 Ave, Kigali',
      employerBusiness: 'Kigali Coffee Holdings',
      notes: 'Created through the new Debtors screen flow.',
    );
    await recProv.createDebtor(newDebtor);

    // ── 4. The new debtor shows up across all clients ────────────────────
    await recProv.loadDebtors();
    final listed = recProv.debtors.firstWhere((d) => d.id == newDebtor.id);
    expect(listed.clientId, org1.id);
    expect(listed.name, 'Kigali Coffee Traders');

    final debtorRows = await db.query(
      'debtors',
      where: 'id = ?',
      whereArgs: [newDebtor.id],
    );
    expect(debtorRows, isNotEmpty, reason: 'new debtor must be persisted');
    expect(debtorRows.first['client_id'], org1.id);
    expect(debtorRows.first['name'], 'Kigali Coffee Traders');

    // Audit trail for the creation must exist (repo-level behaviour).
    final auditRows = await db.query(
      'audit_logs',
      where: "action = 'debtor.create' AND entity_id = ?",
      whereArgs: [newDebtor.id],
    );
    expect(auditRows, isNotEmpty, reason: 'debtor.create must be audited');

    // ── 5. Replicate the New Case dialog → link it to that debtor ────────
    final newCase = CaseModel(
      id: const Uuid().v4(),
      caseNumber: '', // repo auto-generates CASE-YYYY-NNNNNN
      organizationId: org1.id,
      debtorId: newDebtor.id,
      clientReference: 'REF-7712',
      title: 'Overdue Invoice - Kigali Coffee',
      priority: 'High',
      status: 'Open',
      dateReceived: DateTime.now(),
      principal: 1200000.0,
      interest: 0.0,
      penalties: 0.0,
      fees: 0.0,
      totalClaim: 1200000.0,
      difficulty: 'Medium',
    );
    await recProv.createCase(newCase);

    // ── 6. The case is listed and correctly linked to the debtor ────────
    await recProv.loadCases();
    final listedCase = recProv.cases.firstWhere(
      (c) => c.debtorId == newDebtor.id,
    );
    expect(listedCase.caseNumber, startsWith('CASE-'));
    expect(listedCase.organizationId, org1.id);
    expect(listedCase.title, 'Overdue Invoice - Kigali Coffee');
    expect(listedCase.status, 'Open');
    expect(listedCase.clientReference, 'REF-7712');

    // Raw DB row proves the linkage is persisted.
    final caseRows = await db.query(
      'cases',
      where: 'debtor_id = ?',
      whereArgs: [newDebtor.id],
    );
    expect(caseRows, isNotEmpty, reason: 'case must be persisted');
    expect(caseRows.first['debtor_id'], newDebtor.id);
    expect(caseRows.first['organization_id'], org1.id);
    expect(caseRows.first['case_number'], startsWith('CASE-'));

    // The case detail screen resolves "Debtor: <name>" via debtorId — confirm
    // the debtor is still resolvable from the cases view.
    final detailDebtor = recProv.debtors.firstWhere(
      (d) => d.id == listedCase.debtorId,
    );
    expect(detailDebtor.name, 'Kigali Coffee Traders');

    // ── 7. Cross-client guard: a case can't link a debtor to another client ──
    final crossCase = CaseModel(
      id: const Uuid().v4(),
      caseNumber: '',
      organizationId: org2.id, // Metro
      debtorId: newDebtor.id, // belongs to org1 (Telco)
      title: 'Must be rejected',
      priority: 'Low',
      status: 'Open',
      principal: 100.0,
      interest: 0.0,
      penalties: 0.0,
      fees: 0.0,
      totalClaim: 100.0,
      difficulty: 'Easy',
    );
    expect(
      () => recProv.createCase(crossCase),
      throwsA(isA<Exception>()),
      reason: 'CaseRepository must refuse cross-client debtor linking',
    );

    // ── 8. Repository-level masking is real and wired to the session ─────
    // Recovery Officers have debtor.view + debtor.edit but NOT debtor.sensitive.
    final roRoleId =
        (await db.query(
              'roles',
              where: "name = ?",
              whereArgs: ['Recovery Officer'],
              limit: 1,
            )).first['id']
            as String;
    final roPerms = await userRepo.getPermissionsForRole(roRoleId);
    expect(roPerms.contains('debtor.sensitive'), isFalse);
    expect(roPerms.contains('debtor.view'), isTrue);

    final maskedSession = AuthSession(
      userId: session.userId,
      username: session.username,
      roleId: roRoleId,
      roleName: 'Recovery Officer',
      permissions: roPerms,
      loginTime: DateTime.now().toUtc(),
      isSuperAdmin: false,
    );
    debtorRepo.setSession(maskedSession);

    final maskedDebtors = await debtorRepo.getAll();
    final maskedNew = maskedDebtors.firstWhere((d) => d.id == newDebtor.id);
    expect(
      maskedNew.phone,
      '***-***-****',
      reason: 'repo masks phone without debtor.sensitive',
    );
    expect(
      maskedNew.email,
      '***@***.***',
      reason: 'repo masks email without debtor.sensitive',
    );
    expect(
      maskedNew.employerBusiness,
      '*** HIDDEN ***',
      reason: 'repo masks employer without debtor.sensitive',
    );

    // Restore the super-admin session.
    debtorRepo.setSession(session);

    await dbHelper.close();
  });
}
