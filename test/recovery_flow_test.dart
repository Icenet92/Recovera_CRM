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
import 'package:recovera_crm/repositories/recovery_assignment_repository.dart';
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
    final recoveryAssignmentRepo = RecoveryAssignmentRepository(dbHelper);

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
        recoveryAssignmentRepo,
      ],
    );

    // ── 1. Real login as the seeded super-admin ──────────────────────────
    final session = await authRepo.login('admin', 'Admin@1234');
    expect(session.username, 'admin');
    expect(session.isSuperAdmin, isTrue);
    // Sessions must have propagated to EVERY repository (incl. debtor/case).
    expect(debtorRepo.currentSession.username, 'admin');
    expect(caseRepo.currentSession.userId, session.userId);

    final recProv = RecoveryProvider(caseRepo, debtorRepo, recoveryAssignmentRepo);
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

  // ── Phase 3B ────────────────────────────────────────────────────────────
  // Proves the data layer end-to-end: a manager pools 2 of Acme's cases into a
  // batch for a Recovery Officer, the target auto-suggests from outstanding
  // claims, rows + audit trail persist, the active-batch guard rejects reuse,
  // and the provider computes recovered amount (0 until Phase 5) + time-in-progress.
  test('Phase 3B: recovery assignment pools cases with an active-batch guard',
      () async {
    final dir = Directory.systemTemp.createTempSync('recovera_test_3b_');
    addTearDown(() async => dir.delete(recursive: true));

    final dbHelper = DatabaseHelper.withPath(dir.path);
    final db = await dbHelper.database;

    final auditRepo = AuditRepository(dbHelper);
    final userRepo = UserRepository(dbHelper, auditRepo);
    final orgRepo = OrganizationRepository(dbHelper, auditRepo);
    final caseRepo = CaseRepository(dbHelper);
    final debtorRepo = DebtorRepository(dbHelper);
    final recoveryAssignmentRepo = RecoveryAssignmentRepository(dbHelper);

    final authRepo = AuthRepository(
      userRepo,
      auditRepo,
      additionalRepos: [
        orgRepo,
        caseRepo,
        debtorRepo,
        recoveryAssignmentRepo,
      ],
    );

    final session = await authRepo.login('admin', 'Admin@1234');
    expect(session.isSuperAdmin, isTrue);

    final recProv = RecoveryProvider(
      caseRepo,
      debtorRepo,
      recoveryAssignmentRepo,
    );

    // Seeded Acme debtor + Telco org + seeded case CASE-2026-000001.
    final org1Id =
        (await db.query('organizations', where: "company_name = ?", whereArgs: ['Telco One Rwanda'], limit: 1)).first['id'] as String;
    final debtor1Id =
        (await db.query('debtors', where: "name = ?", whereArgs: ['Acme Trading Corp'], limit: 1)).first['id'] as String;
    final case1Row =
        (await db.query('cases', where: "case_number = ?", whereArgs: ['CASE-2026-000001'], limit: 1)).first;
    final case1Id = case1Row['id'] as String;
    final case1Claim = (case1Row['total_claim'] as num).toDouble();

    // Seeded test-only Recovery Officer user (sam.mugisha).
    final officerId =
        (await db.query('users', where: "username = ?", whereArgs: ['sam.mugisha'], limit: 1)).first['id'] as String;
    expect(officerId, isNotEmpty, reason: 'seeded officer must exist');

    // Create a 2nd Acme case to pool alongside the seeded one.
    final case2 = CaseModel(
      id: const Uuid().v4(),
      caseNumber: '',
      organizationId: org1Id,
      debtorId: debtor1Id,
      title: 'Phase 3B Pool Case 2',
      priority: 'Medium',
      status: 'Open',
      dateReceived: DateTime.now(),
      principal: 800000.0,
      interest: 0.0,
      penalties: 0.0,
      fees: 0.0,
      totalClaim: 1200000.0,
      difficulty: 'Medium',
    );
    await recProv.createCase(case2);

    final case2Id =
        (await db.query('cases', where: "title = ?", whereArgs: ['Phase 3B Pool Case 2'], limit: 1)).first['id'] as String;

    // Auto-suggested target = sum of outstanding claims (= total_claim until Phase 5).
    final expectedTarget = case1Claim + 1200000.0;

    final deadline = DateTime.now().add(const Duration(days: 10));
    await recProv.createRecoveryAssignment(
      assignedEmployeeId: officerId,
      assignedBy: session.userId,
      targetAmount: expectedTarget,
      startDate: DateTime.now(),
      deadlineDate: deadline,
      notes: 'Phase 3B demo batch',
      caseIds: [case1Id, case2Id],
    );

    // Persisted assignment row.
    final assignmentRows = await db.query(
      'recovery_assignments',
      where: "assigned_employee_id = ? AND status = 'Active'",
      whereArgs: [officerId],
    );
    expect(assignmentRows, isNotEmpty, reason: 'assignment must persist');
    final assignment = assignmentRows.first;
    expect(assignment['target_amount'], expectedTarget);
    expect(assignment['assigned_employee_id'], officerId);
    expect(assignment['assigned_by'], session.userId);
    expect(assignment['status'], 'Active');

    // Both cases pooled into the batch (membership history).
    final bhRows = await db.query(
      'case_assignment_batch_history',
      where: "recovery_assignment_id = ? AND removed_date IS NULL",
      whereArgs: [assignment['id']],
    );
    expect(bhRows, hasLength(2), reason: 'both cases pooled');
    expect(bhRows.map((r) => r['case_id']).toSet(), {case1Id, case2Id});

    // Audit trail for assignment.create.
    final auditRows = await db.query(
      'audit_logs',
      where: "action = 'assignment.create' AND entity_id = ?",
      whereArgs: [assignment['id']],
    );
    expect(auditRows, isNotEmpty, reason: 'assignment.create must be audited');

    // Reload via provider: detail loads + computed values.
    final assignmentId = assignment['id'] as String;
    await recProv.loadRecoveryAssignment(assignmentId);
    expect(recProv.currentAssignment, isNotNull);
    expect(recProv.currentAssignmentCases, hasLength(2));
    expect(
      recProv.currentAssignmentRecoveredAmount,
      0.0,
      reason: 'no verified payments until Phase 5',
    );

    // Open cases are in-progress → time-to-recovery is now − added_date.
    final ttr = recProv.timeToRecoveryForCase(case1Id);
    expect(ttr, isNotNull);
    expect(ttr!.inSeconds, greaterThanOrEqualTo(0));

    // Row-scope: officer sees only their own batch.
    final officerAssignments =
        await recoveryAssignmentRepo.getByEmployee(officerId);
    expect(officerAssignments, hasLength(1));

    // Active-batch guard: reusing case1 in a 2nd active batch is rejected.
    expect(
      () => recProv.createRecoveryAssignment(
        assignedEmployeeId: officerId,
        assignedBy: session.userId,
        targetAmount: 1000.0,
        startDate: DateTime.now(),
        deadlineDate: deadline,
        notes: 'should be rejected',
        caseIds: [case1Id],
      ),
      throwsA(isA<Exception>()),
      reason: 'case already in an active batch — must be rejected',
    );

    await dbHelper.close();
  });

  // ── Case Detail ─────────────────────────────────────────────────────────
  // Regression for: CaseDetailScreen showed "Debtor: Loading..." forever
  // because loadCaseDetails fetched the case but never its debtor, so the
  // name lookup against the (empty) global `_debtors` list never resolved.
  test('Case Detail debtor resolves via loadCaseDetails', () async {
    final dir = Directory.systemTemp.createTempSync('recovera_test_detail_');
    addTearDown(() async => dir.delete(recursive: true));

    final dbHelper = DatabaseHelper.withPath(dir.path);
    final db = await dbHelper.database;

    final auditRepo = AuditRepository(dbHelper);
    final userRepo = UserRepository(dbHelper, auditRepo);
    final orgRepo = OrganizationRepository(dbHelper, auditRepo);
    final caseRepo = CaseRepository(dbHelper);
    final debtorRepo = DebtorRepository(dbHelper);
    final recoveryAssignmentRepo = RecoveryAssignmentRepository(dbHelper);
    final authRepo = AuthRepository(
      userRepo,
      auditRepo,
      additionalRepos: [
        orgRepo,
        caseRepo,
        debtorRepo,
        recoveryAssignmentRepo,
      ],
    );

    // Logged-in super-admin session (propagated to the repos above).
    await authRepo.login('admin', 'Admin@1234');

    final recProv = RecoveryProvider(
      caseRepo,
      debtorRepo,
      recoveryAssignmentRepo,
    );

    // Seeded case CASE-2026-000001 -> its debtor (Acme Trading Corp).
    final caseRow = (await db.query(
      'cases',
      where: "case_number = ?",
      whereArgs: ['CASE-2026-000001'],
      limit: 1,
    )).first;
    final caseId = caseRow['id'] as String;
    final debtorId = caseRow['debtor_id'] as String;
    final debtorRow = (await db.query(
      'debtors',
      where: "id = ?",
      whereArgs: [debtorId],
      limit: 1,
    )).first;

    // Simulate landing on Case Detail from a client's Cases tab: the global
    // debtors list was never loaded.
    expect(recProv.debtors, isEmpty, reason: 'debtors start empty');

    await recProv.loadCaseDetails(caseId);

    // The fix: loadCaseDetails must pull the case's debtor into `_debtors` so
    // CaseDetailScreen's `recProv.debtors.where((d)=>d.id==c.debtorId).firstOrNull`
    // resolves instead of falling back to 'Loading...'.
    final resolved = recProv.debtors.where((d) => d.id == debtorId);
    expect(resolved, hasLength(1), reason: 'case debtor must resolve');
    expect(resolved.first.name, debtorRow['name'] as String);
    expect(resolved.first.id, debtorId);

    expect(recProv.currentCase, isNotNull);
    expect(recProv.caseDetailsLoaded, isTrue);

    await dbHelper.close();
  });
}
