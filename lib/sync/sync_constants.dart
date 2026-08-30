// Fixed port for Master HTTP server
const int kServerPort = 47474;

// HTTP endpoint paths
const String kEndpointHealth = '/health';
const String kEndpointSyncPull = '/sync/pull';
const String kEndpointSyncPush = '/sync/push';
const String kEndpointRole = '/role';
const String kEndpointKeyCheck = '/key-check';

// Timing
const int kHeartbeatIntervalSeconds = 10;
const int kSyncIntervalSeconds = 15;
const int kLockExpirySeconds = 30;
const int kMasterDiscoveryTimeoutSeconds = 10;
const int kMissedHeartbeatsBeforeOffline = 2;

// Role strings
const String kRoleMaster = 'master';
const String kRoleWorker = 'worker';

// mDNS service type
const String kMdnsServiceType = '_recovera._tcp';
const String kMdnsServiceName = 'RecoveraSync';

// HTTP header
const String kOfficeKeyHeader = 'X-Office-Key';

// List of table names that participate in delta sync.
// Phase 1: core org structure
// Phase 2: CRM entities (organizations, contacts, leads, opportunities, activities)
// Phase 3: Cases & debtors + their audit/assignment sub-tables
// Local-only tables (network_config, sync_state, distributed_locks, sync_conflicts) are excluded —
// they are device-local ephemeral / replication-metadata state that must never replicate.
const List<String> kSyncedTables = [
  // Phase 1
  'users', 'employees', 'roles', 'permissions', 'role_permissions',
  'departments', 'teams', 'audit_logs',
  // Phase 2 — CRM
  'organizations', 'contacts', 'leads', 'opportunities', 'crm_activities',
  // Phase 3 — Cases & Debtors
  'debtors', 'cases', 'case_types', 'case_statuses',
  'case_assignments', 'case_status_history', 'case_supporting_employees',
  // Phase 3B — Recovery Assignments (Case Pools)
  'recovery_assignments', 'case_assignment_batch_history',
];
