import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';

Future<void> seedAll(Database db) async {
  final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM roles');
  final count = countResult.isNotEmpty
      ? (countResult.first['count'] as int? ?? 0)
      : 0;
  if (count > 0) return;

  final now = DateTime.now().toUtc().toIso8601String();
  const uuid = Uuid();

  // Roles
  final superAdminId = uuid.v4();
  final execDirectorId = uuid.v4();
  final managerId = uuid.v4();
  final caseManagerId = uuid.v4();
  final recoveryOfficerId = uuid.v4();
  final bdoId = uuid.v4();
  final financeOfficerId = uuid.v4();
  final auditorId = uuid.v4();

  final roles = [
    {
      'id': superAdminId,
      'name': 'Super Administrator',
      'description': 'Full access',
    },
    {
      'id': execDirectorId,
      'name': 'Executive/Director',
      'description': 'Executive oversight',
    },
    {'id': managerId, 'name': 'Manager', 'description': 'Team management'},
    {
      'id': caseManagerId,
      'name': 'Case Manager',
      'description': 'Manages cases',
    },
    {
      'id': recoveryOfficerId,
      'name': 'Recovery Officer',
      'description': 'Handles recoveries',
    },
    {
      'id': bdoId,
      'name': 'Business Development Officer',
      'description': 'Handles clients and leads',
    },
    {
      'id': financeOfficerId,
      'name': 'Finance Officer',
      'description': 'Handles finances',
    },
    {
      'id': auditorId,
      'name': 'Auditor',
      'description': 'Read-only audit access',
    },
  ];

  await db.transaction((txn) async {
    for (var role in roles) {
      await txn.insert('roles', {
        ...role,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    }

    final perms = [
      {'code': 'user.create', 'name': 'Create User', 'category': 'users'},
      {'code': 'user.edit', 'name': 'Edit User', 'category': 'users'},
      {'code': 'user.delete', 'name': 'Delete User', 'category': 'users'},
      {'code': 'user.view', 'name': 'View User', 'category': 'users'},
      {'code': 'role.assign', 'name': 'Assign Role', 'category': 'roles'},
      {'code': 'role.view', 'name': 'View Role', 'category': 'roles'},
      {'code': 'kpi.configure', 'name': 'Configure KPI', 'category': 'kpi'},
      {'code': 'kpi.view', 'name': 'View KPI', 'category': 'kpi'},
      {'code': 'audit.view', 'name': 'View Audit', 'category': 'audit'},
      {
        'code': 'settings.edit',
        'name': 'Edit Settings',
        'category': 'settings',
      },
      {
        'code': 'network.manage',
        'name': 'Manage Network',
        'category': 'network',
      },
      {'code': 'case.create', 'name': 'Create Case', 'category': 'cases'},
      {'code': 'case.edit', 'name': 'Edit Case', 'category': 'cases'},
      {'code': 'case.close', 'name': 'Close Case', 'category': 'cases'},
      {'code': 'case.reopen', 'name': 'Reopen Case', 'category': 'cases'},
      {'code': 'case.assign', 'name': 'Assign Case', 'category': 'cases'},
      {'code': 'case.view', 'name': 'View Case', 'category': 'cases'},
      {
        'code': 'payment.record',
        'name': 'Record Payment',
        'category': 'payments',
      },
      {
        'code': 'payment.verify',
        'name': 'Verify Payment',
        'category': 'payments',
      },
      {'code': 'report.export', 'name': 'Export Report', 'category': 'reports'},
      {
        'code': 'document.upload',
        'name': 'Upload Document',
        'category': 'documents',
      },
      {
        'code': 'document.view',
        'name': 'View Document',
        'category': 'documents',
      },
      // Phase 2 — CRM
      {'code': 'crm.view', 'name': 'View CRM', 'category': 'crm'},
      {'code': 'crm.create', 'name': 'Create CRM Record', 'category': 'crm'},
      {'code': 'crm.edit', 'name': 'Edit CRM Record', 'category': 'crm'},
      {'code': 'crm.delete', 'name': 'Delete CRM Record', 'category': 'crm'},
      {'code': 'lead.manage', 'name': 'Manage Leads', 'category': 'crm'},
      // Phase 3 — Debtors
      {'code': 'debtor.view', 'name': 'View Debtor', 'category': 'debtors'},
      {'code': 'debtor.edit', 'name': 'Edit Debtor', 'category': 'debtors'},
      {
        'code': 'debtor.sensitive',
        'name': 'View Sensitive Debtor Info',
        'category': 'debtors',
      },
      // Phase 3B — Recovery Assignments (Case Pools)
      {'code': 'assignment.view', 'name': 'View Assignment', 'category': 'assignments'},
      {'code': 'assignment.create', 'name': 'Create Assignment', 'category': 'assignments'},
      {'code': 'assignment.edit', 'name': 'Edit Assignment', 'category': 'assignments'},
      {'code': 'assignment.delete', 'name': 'Delete Assignment', 'category': 'assignments'},
    ];

    final permIds = <String, String>{};
    for (var p in perms) {
      final pId = uuid.v4();
      permIds[p['code']!] = pId;
      await txn.insert('permissions', {
        'id': pId,
        'code': p['code'],
        'name': p['name'],
        'description': p['name'],
        'category': p['category'],
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    }

    void assignPerms(String rId, List<String> codes) {
      for (var code in codes) {
        if (!permIds.containsKey(code)) continue;
        txn.insert('role_permissions', {
          'id': uuid.v4(),
          'role_id': rId,
          'permission_id': permIds[code],
          'SyncCreatedAt': now,
          'SyncUpdatedAt': now,
          'IsDeleted': 0,
          'DeletedAt': null,
        });
      }
    }

    assignPerms(superAdminId, perms.map((e) => e['code']!).toList());
    assignPerms(execDirectorId, [
      'kpi.view',
      'audit.view',
      'report.export',
      'case.view',
      'user.view',
      'role.view',
      'document.view',
      'payment.verify',
      'crm.view',
      'debtor.view',
      'assignment.view',
    ]);
    assignPerms(managerId, [
      'kpi.view',
      'kpi.configure',
      'audit.view',
      'report.export',
      'case.create',
      'case.edit',
      'case.close',
      'case.reopen',
      'case.assign',
      'user.view',
      'document.upload',
      'document.view',
      'payment.verify',
      'crm.view',
      'crm.create',
      'crm.edit',
      'crm.delete',
      'lead.manage',
      'debtor.view',
      'debtor.edit',
      'debtor.sensitive',
      'assignment.view',
      'assignment.create',
      'assignment.edit',
    ]);
    assignPerms(caseManagerId, [
      'case.create',
      'case.edit',
      'case.close',
      'case.assign',
      'kpi.view',
      'document.upload',
      'document.view',
      'payment.record',
      'case.view',
      'crm.view',
      'crm.create',
      'crm.edit',
      'lead.manage',
      'debtor.view',
      'debtor.edit',
      'debtor.sensitive',
      'assignment.view',
      'assignment.create',
      'assignment.edit',
    ]);
    assignPerms(recoveryOfficerId, [
      'case.edit',
      'kpi.view',
      'document.upload',
      'document.view',
      'payment.record',
      'case.view',
      'crm.view',
      'debtor.view',
      'debtor.edit',
      'assignment.view',
    ]);
    assignPerms(bdoId, [
      'case.create',
      'case.view',
      'document.view',
      'report.export',
      'crm.view',
      'crm.create',
      'crm.edit',
      'crm.delete',
      'lead.manage',
      'debtor.view',
    ]);
    assignPerms(financeOfficerId, [
      'payment.record',
      'payment.verify',
      'report.export',
      'document.view',
      'crm.view',
      'debtor.view',
    ]);
    assignPerms(auditorId, [
      'audit.view',
      'kpi.view',
      'report.export',
      'document.view',
      'case.view',
      'user.view',
      'crm.view',
      'debtor.view',
    ]);

    // Hash Admin@1234 using the PBKDF2 scheme in AuthService
    final salt = AuthService.generateSalt();
    final hash = AuthService.hashPassword('Admin@1234', salt);

    final adminUserId = uuid.v4();
    await txn.insert('users', {
      'id': adminUserId,
      'username': 'admin',
      'password_hash': hash,
      'password_salt': salt,
      'role_id': superAdminId,
      'is_active': 1,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // TEST/SEED DATA ONLY — do NOT ship as a real account.
    // A Recovery Officer used by the Phase 3B tests and the demo Create-flow
    // picker. `assigned_employee_id` holds a user id (see model/repo docs), so
    // this user stands in for an "assignable officer". Remove before any
    // client-facing deployment.
    final officerSalt = AuthService.generateSalt();
    final officerHash = AuthService.hashPassword('Agent@1234', officerSalt);
    final recoveryOfficerUserId = uuid.v4();
    await txn.insert('users', {
      'id': recoveryOfficerUserId,
      'username': 'sam.mugisha',
      'password_hash': officerHash,
      'password_salt': officerSalt,
      'employee_id': null,
      'role_id': recoveryOfficerId,
      'is_active': 1,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // ── PHASE 2: Demo seed data (fictional companies) ──────────────────────────
    final org1Id = uuid.v4();
    final org2Id = uuid.v4();

    await txn.insert('organizations', {
      'id': org1Id,
      'company_name': 'Telco One Rwanda',
      'registration_number': 'RCA-2019-001',
      'industry': 'Telecommunications',
      'address': 'KG 7 Ave, Kigali',
      'phone': '+250 788 100 001',
      'email': 'info@telco1rw.rw',
      'status': 'Active',
      'lead_source': 'Referral',
      'notes': 'Demo client — seeded for testing.',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('organizations', {
      'id': org2Id,
      'company_name': 'Metro Insurance Ltd',
      'registration_number': 'RCA-2020-045',
      'industry': 'Insurance',
      'address': 'KN 4 Rd, Kigali',
      'phone': '+250 788 200 002',
      'email': 'contact@metroins.rw',
      'status': 'Negotiating',
      'lead_source': 'Cold Outreach',
      'notes': 'Demo client — seeded for testing.',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // Demo contacts
    final contact1Id = uuid.v4();
    final contact2Id = uuid.v4();

    await txn.insert('contacts', {
      'id': contact1Id,
      'organization_id': org1Id,
      'first_name': 'Jean-Paul',
      'last_name': 'Nkurunziza',
      'position': 'Finance Manager',
      'phone': '+250 788 111 111',
      'email': 'jp.nkurunziza@telco1rw.rw',
      'preferred_channel': 'Email',
      'role_type': 'Finance',
      'is_decision_maker': 1,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('contacts', {
      'id': contact2Id,
      'organization_id': org2Id,
      'first_name': 'Aline',
      'last_name': 'Uwimana',
      'position': 'Operations Director',
      'phone': '+250 788 222 222',
      'email': 'a.uwimana@metroins.rw',
      'preferred_channel': 'Phone',
      'role_type': 'Operations',
      'is_decision_maker': 1,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // Demo leads
    await txn.insert('leads', {
      'id': uuid.v4(),
      'organization_id': org1Id,
      'title': 'Telco One — Agent Recovery Contract',
      'source': 'Referral',
      'expected_value': 5000000.0,
      'currency': 'RWF',
      'status': 'Negotiation',
      'next_action': 'Send contract draft',
      'followup_date': DateTime.now()
          .add(const Duration(days: 3))
          .toUtc()
          .toIso8601String(),
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('leads', {
      'id': uuid.v4(),
      'organization_id': org2Id,
      'title': 'Metro Insurance — Claims Recovery',
      'source': 'Cold Outreach',
      'expected_value': 2500000.0,
      'currency': 'RWF',
      'status': 'Meeting',
      'next_action': 'Schedule initial meeting',
      'followup_date': DateTime.now()
          .add(const Duration(days: 7))
          .toUtc()
          .toIso8601String(),
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // Demo activities
    await txn.insert('crm_activities', {
      'id': uuid.v4(),
      'activity_type': 'Call',
      'subject': 'Initial qualification call',
      'description':
          'Discussed scope of agent debt recovery. Client confirmed interest.',
      'outcome': 'Client is interested — proceeding to proposal.',
      'organization_id': org1Id,
      'contact_id': contact1Id,
      'activity_date': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('crm_activities', {
      'id': uuid.v4(),
      'activity_type': 'Meeting',
      'subject': 'Discovery meeting',
      'description':
          'Met with Aline to understand claims portfolio and timeline.',
      'outcome': 'Agreed to send a capabilities deck.',
      'organization_id': org2Id,
      'contact_id': contact2Id,
      'activity_date': now,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    // ── PHASE 3: Cases & Debtors Demo Data ─────────────────────────────────
    final caseType1Id = uuid.v4();
    final caseStatus1Id = uuid.v4();

    await txn.insert('case_types', {
      'id': caseType1Id,
      'name': 'Corporate Default',
      'description': 'Default by a corporate entity on service payments.',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('case_statuses', {
      'id': caseStatus1Id,
      'name': 'Open',
      'description': 'Case is open and active.',
      'is_closed': 0,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('case_statuses', {
      'id': uuid.v4(),
      'name': 'Closed - Recovered',
      'description': 'Case is closed and fully recovered.',
      'is_closed': 1,
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    final debtor1Id = uuid.v4();
    await txn.insert('debtors', {
      'id': debtor1Id,
      'client_id': org1Id, // Belongs to Telco One Rwanda
      'name': 'Acme Trading Corp',
      'type': 'Company',
      'phone': '+250 788 999 999',
      'email': 'default@acmetrading.rw',
      'address': 'KK 15 Ave, Kigali',
      'employer_business': 'Acme Holdings',
      'notes': 'Demo debtor — seeded for testing.',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    final case1Id = uuid.v4();
    await txn.insert('cases', {
      'id': case1Id,
      'case_number': 'CASE-2026-000001',
      'organization_id': org1Id, // Belongs to Telco One
      'debtor_id': debtor1Id,
      'client_reference': 'REF-9921',
      'title': 'Unpaid Vendor Fees - Acme Trading',
      'case_type': 'Corporate Default',
      'description': 'Debtor failed to pay 3 months of vendor service fees.',
      'priority': 'High',
      'status': 'Open',
      'primary_owner_id': adminUserId, // Assign to Super Admin for easy viewing
      'date_received': now,
      'deadline': DateTime.now()
          .add(const Duration(days: 30))
          .toUtc()
          .toIso8601String(),
      'principal': 4500000.0,
      'interest': 250000.0,
      'penalties': 150000.0,
      'fees': 100000.0,
      'total_claim': 5000000.0,
      'difficulty': 'Medium',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('case_assignments', {
      'id': uuid.v4(),
      'case_id': case1Id,
      'assigned_by_employee_id': adminUserId,
      'assigned_to_employee_id': adminUserId,
      'assignment_date': now,
      'reason': 'Initial case creation assignment.',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });

    await txn.insert('case_status_history', {
      'id': uuid.v4(),
      'case_id': case1Id,
      'changed_by_employee_id': adminUserId,
      'new_status': 'Open',
      'change_date': now,
      'reason': 'Case opened.',
      'SyncCreatedAt': now,
      'SyncUpdatedAt': now,
      'IsDeleted': 0,
      'DeletedAt': null,
    });
  });
}
