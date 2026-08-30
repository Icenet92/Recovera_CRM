import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> createAllTables(Database db) async {
  await db.transaction((txn) async {
    // 1. users
    await txn.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        employee_id TEXT,
        role_id TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_login TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 2. employees
    await txn.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        department_id TEXT,
        team_id TEXT,
        job_title TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 3. roles
    await txn.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 4. permissions
    await txn.execute('''
      CREATE TABLE permissions (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 5. role_permissions
    await txn.execute('''
      CREATE TABLE role_permissions (
        id TEXT PRIMARY KEY,
        role_id TEXT NOT NULL,
        permission_id TEXT NOT NULL,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 6. departments
    await txn.execute('''
      CREATE TABLE departments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 7. teams
    await txn.execute('''
      CREATE TABLE teams (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department_id TEXT,
        leader_employee_id TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 8. audit_logs
    await txn.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        old_value TEXT,
        new_value TEXT,
        timestamp TEXT NOT NULL,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // ── PHASE 2: CRM ──────────────────────────────────────────────────────────

    // 9. organizations (clients — the companies that hire Recovera)
    await txn.execute('''\
      CREATE TABLE organizations (
        id TEXT PRIMARY KEY,
        company_name TEXT NOT NULL,
        registration_number TEXT,
        industry TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        status TEXT NOT NULL DEFAULT 'Prospect',
        account_manager_employee_id TEXT,
        date_acquired TEXT,
        lead_source TEXT,
        contract_start_date TEXT,
        contract_end_date TEXT,
        notes TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 10. contacts (a specific person at an organization)
    await txn.execute('''\
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        position TEXT,
        phone TEXT,
        email TEXT,
        preferred_channel TEXT,
        role_type TEXT NOT NULL DEFAULT 'Primary',
        is_decision_maker INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        last_interaction_date TEXT,
        next_followup_date TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 11. leads (pipeline entries for prospective clients)
    await txn.execute('''\
      CREATE TABLE leads (
        id TEXT PRIMARY KEY,
        organization_id TEXT,
        title TEXT NOT NULL,
        owner_employee_id TEXT,
        source TEXT,
        expected_value REAL,
        currency TEXT NOT NULL DEFAULT 'RWF',
        status TEXT NOT NULL DEFAULT 'New',
        next_action TEXT,
        followup_date TEXT,
        notes TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 12. opportunities (formal opportunity attached to a lead)
    await txn.execute('''\
      CREATE TABLE opportunities (
        id TEXT PRIMARY KEY,
        lead_id TEXT,
        organization_id TEXT,
        title TEXT NOT NULL,
        expected_value REAL,
        probability_pct INTEGER NOT NULL DEFAULT 0,
        close_date TEXT,
        status TEXT NOT NULL DEFAULT 'Open',
        notes TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 13. crm_activities (every interaction with a lead or contact — single source of truth)
    await txn.execute('''\
      CREATE TABLE crm_activities (
        id TEXT PRIMARY KEY,
        activity_type TEXT NOT NULL,
        subject TEXT NOT NULL,
        description TEXT,
        outcome TEXT,
        contact_id TEXT,
        lead_id TEXT,
        organization_id TEXT,
        logged_by_employee_id TEXT,
        activity_date TEXT NOT NULL,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // ── PHASE 3: Cases & Debtors ──────────────────────────────────────────────
    
    // 14. debtors
    await txn.execute('''\
      CREATE TABLE debtors (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        employer_business TEXT,
        notes TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 15. cases
    await txn.execute('''\
      CREATE TABLE cases (
        id TEXT PRIMARY KEY,
        case_number TEXT UNIQUE NOT NULL,
        organization_id TEXT NOT NULL,
        debtor_id TEXT NOT NULL,
        client_reference TEXT,
        title TEXT NOT NULL,
        case_type TEXT,
        description TEXT,
        priority TEXT NOT NULL DEFAULT 'Medium',
        status TEXT NOT NULL DEFAULT 'Open',
        primary_owner_id TEXT,
        supervisor_id TEXT,
        date_received TEXT,
        deadline TEXT,
        date_closed TEXT,
        principal REAL NOT NULL DEFAULT 0,
        interest REAL NOT NULL DEFAULT 0,
        penalties REAL NOT NULL DEFAULT 0,
        fees REAL NOT NULL DEFAULT 0,
        total_claim REAL NOT NULL DEFAULT 0,
        difficulty TEXT NOT NULL DEFAULT 'Medium',
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 16. case_types (configurable list of case types)
    await txn.execute('''\
      CREATE TABLE case_types (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 17. case_statuses (configurable list of case statuses)
    await txn.execute('''\
      CREATE TABLE case_statuses (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        is_closed INTEGER NOT NULL DEFAULT 0,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 18. case_assignments (audit trail for reassignments)
    await txn.execute('''\
      CREATE TABLE case_assignments (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        assigned_by_employee_id TEXT NOT NULL,
        assigned_to_employee_id TEXT NOT NULL,
        supervisor_id TEXT,
        assignment_date TEXT NOT NULL,
        reason TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 20. case_supporting_employees (multiple supporting officers per case)
    await txn.execute('''\
      CREATE TABLE case_supporting_employees (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        employee_id TEXT NOT NULL,
        added_by_employee_id TEXT NOT NULL,
        added_date TEXT NOT NULL,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 19. case_status_history (audit trail for status changes)
    await txn.execute('''\
      CREATE TABLE case_status_history (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        changed_by_employee_id TEXT NOT NULL,
        old_status TEXT,
        new_status TEXT NOT NULL,
        change_date TEXT NOT NULL,
        reason TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 21. recovery_assignments (Phase 3B batch/pool wrapper)
    await txn.execute('''
      CREATE TABLE recovery_assignments (
        id TEXT PRIMARY KEY,
        assigned_employee_id TEXT NOT NULL,
        assigned_by TEXT NOT NULL,
        target_amount REAL NOT NULL,
        start_date TEXT NOT NULL,
        deadline_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        notes TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // 22. case_assignment_batch_history (cases pooled into a recovery assignment)
    await txn.execute('''
      CREATE TABLE case_assignment_batch_history (
        id TEXT PRIMARY KEY,
        recovery_assignment_id TEXT NOT NULL,
        case_id TEXT NOT NULL,
        added_date TEXT NOT NULL,
        removed_date TEXT,
        SyncCreatedAt TEXT NOT NULL,
        SyncUpdatedAt TEXT NOT NULL,
        IsDeleted INTEGER NOT NULL DEFAULT 0,
        DeletedAt TEXT
      )
    ''');

    // LOCAL-ONLY TABLES

    // 9. network_config
    await txn.execute('''
      CREATE TABLE network_config (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        network_role TEXT NOT NULL,
        office_key TEXT,
        office_name TEXT,
        master_ip TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 10. sync_state
    await txn.execute('''
      CREATE TABLE sync_state (
        id TEXT PRIMARY KEY,
        table_name TEXT UNIQUE NOT NULL,
        last_synced_updated_at TEXT NOT NULL DEFAULT '1970-01-01 00:00:00'
      )
    ''');

    // 11. distributed_locks
    await txn.execute('''
      CREATE TABLE distributed_locks (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        lock_mode TEXT NOT NULL DEFAULT 'edit',
        acquired_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        role_priority INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 12. sync_conflicts
    await txn.execute('''
      CREATE TABLE sync_conflicts (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        winner_device_id TEXT NOT NULL,
        loser_device_id TEXT NOT NULL,
        winner_updated_at TEXT NOT NULL,
        loser_updated_at TEXT NOT NULL,
        resolved_at TEXT NOT NULL
      )
    ''');

    // INDEXES
    await txn.execute('CREATE INDEX idx_users_username ON users(username)');
    await txn.execute('CREATE INDEX idx_employees_email ON employees(email)');
    await txn.execute('CREATE INDEX idx_role_permissions_role_id_permission_id ON role_permissions(role_id, permission_id)');
    await txn.execute('CREATE INDEX idx_audit_logs_user_id_timestamp ON audit_logs(user_id, timestamp)');
    await txn.execute('CREATE INDEX idx_distributed_locks_entity_type_entity_id ON distributed_locks(entity_type, entity_id)');
    await txn.execute('CREATE INDEX idx_distributed_locks_expires_at ON distributed_locks(expires_at)');
    await txn.execute('CREATE INDEX idx_sync_conflicts_table_name_record_id ON sync_conflicts(table_name, record_id)');

    // Phase 2 CRM indexes
    await txn.execute('CREATE INDEX idx_organizations_status ON organizations(status)');
    await txn.execute('CREATE INDEX idx_organizations_company_name ON organizations(company_name)');
    await txn.execute('CREATE INDEX idx_contacts_organization_id ON contacts(organization_id)');
    await txn.execute('CREATE INDEX idx_leads_status ON leads(status)');
    await txn.execute('CREATE INDEX idx_leads_owner ON leads(owner_employee_id)');
    await txn.execute('CREATE INDEX idx_crm_activities_organization_id ON crm_activities(organization_id)');
    await txn.execute('CREATE INDEX idx_crm_activities_contact_id ON crm_activities(contact_id)');
    await txn.execute('CREATE INDEX idx_crm_activities_lead_id ON crm_activities(lead_id)');
    await txn.execute('CREATE INDEX idx_crm_activities_date ON crm_activities(activity_date)');

    // Phase 3 Cases indexes
    await txn.execute('CREATE INDEX idx_debtors_client_id ON debtors(client_id)');
    await txn.execute('CREATE INDEX idx_cases_organization_id ON cases(organization_id)');
    await txn.execute('CREATE INDEX idx_cases_debtor_id ON cases(debtor_id)');
    await txn.execute('CREATE INDEX idx_cases_primary_owner_id ON cases(primary_owner_id)');
    await txn.execute('CREATE INDEX idx_cases_status ON cases(status)');
    await txn.execute('CREATE INDEX idx_case_assignments_case_id ON case_assignments(case_id)');
    await txn.execute('CREATE INDEX idx_case_status_history_case_id ON case_status_history(case_id)');
    await txn.execute('CREATE INDEX idx_case_supporting_employees_case_id ON case_supporting_employees(case_id)');
  });
}
