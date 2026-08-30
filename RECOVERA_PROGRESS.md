# RECOVERA — Build Progress Tracker

> **Purpose:** Track what has been built, what is in progress, and what is pending across all phases.  
> **Update this file at the end of every phase.**

---

## Legend
- ✅ Done & verified
- 🔄 In Progress
- ⬜ Not Started
- ⚠️ Needs Attention / Known Issues

---

## PHASE 0 — Architecture Decisions ✅

**Completed:** 2026-08-25  
**Status:** ✅ Done

### What was established
- **Tech Stack locked:** Flutter/Windows, Provider, sqflite_common_ffi, bitsdojo_window, Google Fonts Inter, local_notifier, bonsoir (mDNS), http, shelf/shelf_router
- **Architecture pattern fixed:** Repository layer is the only thing that touches SQLite; screens and providers never query the DB directly
- **Sync architecture:** `SyncAdapter` interface (`pushChanges`, `pullChanges(since)`, `getConnectionStatus`), only `LanSyncAdapter` built now — `SupabaseSyncAdapter` reserved for Phase 10
- **Sync columns:** Every synced table gets `SyncCreatedAt`, `SyncUpdatedAt`, `IsDeleted`, `DeletedAt` from day one
- **Non-negotiable principles confirmed:** KPIs from real data only, every KPI clickable to underlying records, every button works, no hard-deletes on financial data, no building ahead of phase

### Files established
| File | Purpose |
|------|---------|
| `pubspec.yaml` | All dependencies locked |
| `lib/sync/sync_adapter.dart` | `SyncAdapter` interface |
| `lib/sync/lan_sync_adapter.dart` | LAN Master/Worker implementation |
| `lib/sync/sync_server.dart` | HTTP server (Master side) |
| `lib/sync/sync_client.dart` | HTTP client (Worker side) |
| `lib/sync/sync_discovery.dart` | mDNS discovery (bonsoir) |
| `lib/sync/sync_models.dart` | Sync DTOs |
| `lib/sync/sync_constants.dart` | Shared constants |
| `lib/sync/lock_engine.dart` | Distributed lock management |
| `lib/sync/sync_conflict_resolver.dart` | Conflict resolution (last-write-wins by SyncUpdatedAt) |

---

## PHASE 1 — Foundation: DB, Auth, Roles, Navigation Shell ✅

**Completed:** 2026-08-25  
**Status:** ✅ Done

### What was built

#### Database Schema (`lib/database/schema.dart`)
- Tables created: `users`, `employees`, `roles`, `permissions`, `role_permissions`, `departments`, `teams`, `audit_logs`
- Local-only tables: `network_config`, `sync_state`, `distributed_locks`, `sync_conflicts`
- All synced tables have `SyncCreatedAt`, `SyncUpdatedAt`, `IsDeleted`, `DeletedAt` ✅
- UUID primary keys on all tables ✅
- Indexes on `users.username`, `employees.email`, `role_permissions(role_id, permission_id)`, `audit_logs(user_id, timestamp)` ✅

#### Seed Data (`lib/database/seeds.dart`)
- 8 roles seeded: Super Administrator, Executive/Director, Manager, Case Manager, Recovery Officer, Business Development Officer, Finance Officer, Auditor ✅
- 22 permissions seeded across categories: users, roles, kpi, audit, settings, network, cases, payments, reports, documents ✅
- Role-permission assignments per spec ✅
- Default `admin` user seeded (password: `Admin@1234`) ✅

#### Auth System
- `lib/services/auth_service.dart` — password hashing (SHA-256 + salt), salt generation ✅
- `lib/repositories/auth_repository.dart` — login/logout, session management, audit logging ✅
- `lib/repositories/user_repository.dart` — createUser, updateUser, softDelete, changePassword, getPermissionsForRole ✅
- `lib/repositories/audit_repository.dart` — append-only audit log writer ✅
- `lib/repositories/base_repository.dart` — `requirePermission()` enforced at data-access layer, not UI ✅
- `lib/models/auth_session.dart` — session model with `hasPermission()` ✅
- `lib/models/user_model.dart`, `role_model.dart`, `employee_model.dart` — core models ✅

#### Providers
- `lib/providers/auth_provider.dart` — ChangeNotifier wrapping AuthRepository ✅
- `lib/providers/sync_provider.dart` — ChangeNotifier wrapping LanSyncAdapter ✅

#### App Shell & Navigation
- `lib/main.dart` — app entry, DB init, repo wiring, bitsdojo_window setup ✅
- `lib/screens/login_screen.dart` — login form, error display ✅
- `lib/screens/network_setup_screen.dart` — Master/Worker bootstrap UI ✅
- `lib/screens/shell/app_shell.dart` — custom title bar (bitsdojo_window), sidebar + content area ✅
- `lib/screens/shell/sidebar.dart` — permission-filtered nav: Dashboard, CRM (Leads/Clients/Contacts), Recovery (Cases/Debtors/Payments/Promises), Work (Tasks/Activities/Calendar), Performance (3 screens), Documents, Reports, Organization (Employees/Teams), Administration (Users/Roles/Audit Log/Network Setup/Settings) ✅

### Known gaps / things to watch
- Password hashing uses SHA-256+salt (crypto package). Acceptable for V1 internal LAN use; PBKDF2/bcrypt would be stronger — flag for Phase 9 hardening pass.
- Device ID in `main.dart` is hardcoded `'DEVICE-1234'`; needs `device_info_plus` in Phase 9 hardening.
- `payment.view` permission referenced in sidebar but not seeded — sidebar gracefully hides it. Non-blocking.
- All content panes show `"Coming in Phase N: [route]"` placeholder — correct, to be replaced phase by phase.

---

## PHASE 2 — CRM: Leads, Clients, Contacts ✅

**Completed:** 2026-08-25  
**Status:** ✅ Done

### What was built

#### Database Schema (`lib/database/schema.dart`)
- Tables created: `organizations`, `contacts`, `leads`, `opportunities`, `crm_activities`
- All synced tables have `SyncCreatedAt`, `SyncUpdatedAt`, `IsDeleted`, `DeletedAt` ✅
- UUID primary keys on all tables ✅
- Indexes added for CRM queries (e.g., status, organization_id, contact_id, date) ✅

#### Seed Data (`lib/database/seeds.dart`)
- 5 permissions seeded: `crm.view`, `crm.create`, `crm.edit`, `crm.delete`, `lead.manage`
- Role-permission assignments updated for CRM capabilities ✅
- Demo seed data: 2 organizations, 2 contacts, 2 leads, 2 activities ✅

#### Models & Repositories
- Data models with `fromMap`/`toMap`/`copyWith` implemented for all CRM entities ✅
- Repositories built with permission checks (`requirePermission()`) and audit logging (`crm.*` actions) ✅
- `CrmActivityRepository` acts as the single source of truth for CRM logging, with complex join queries to retrieve timeline activities.

#### Providers
- `CrmProvider` wraps the CRM repositories, managing states for organizations, contacts, leads, activities, and search results.
- Exposes `leadsByStage` helper for Kanban logic.

#### App Shell & Navigation
- Sidebar navigation for CRM fully functional.
- `ClientsScreen`: Filterable, searchable client list.
- `ClientDetailScreen`: 5-tab layout (Overview, Contacts, Activities, Cases [locked], Financial [locked]).
- `LeadsScreen`: Draggable Kanban board with dynamic stages and status indication.
- `ContactsScreen`: Cross-organization search.
- Dialogs: `ClientFormDialog`, `ContactFormDialog`, `LeadFormDialog`, `LogActivityDialog`.

### Completion criteria met
- [x] Create a client, add contacts, log an activity against a contact
- [x] Move a lead through the pipeline on the Kanban board
- [x] All reflected on the client's timeline

---

## PHASE 3 — Cases, Debtors, Assignment ✅

**Completed:** 2026-08-26  
**Status:** ✅ Done

### What was built

#### Database Schema & Seed Data (`lib/database/schema.dart` & `seeds.dart`)
- Tables created: `debtors`, `cases`, `case_types`, `case_statuses`, `case_assignments`, `case_status_history`
- Seeded new permissions: `case.view`, `case.create`, `case.edit`, `case.assign`, `case.close`, `case.reopen`, `debtor.view`, `debtor.edit`, `debtor.sensitive`
- Seeded test data for demo case and debtor

#### Repositories & Models
- Models implemented with `copyWith`/`fromMap`/`toMap`. `CaseModel` includes computed `outstandingAmount` based on `totalClaim`.
- `DebtorRepository`: includes dynamic data masking (redacting phone, email, employer) if user lacks `debtor.sensitive` permission.
- `CaseRepository`: implements `_generateCaseNumber` for sequential `CASE-YYYY-XXXXXX` IDs. Audit logs assignments and status changes into specific history tables plus the master `audit_logs` table using transactions.

#### Providers & UI
- `RecoveryProvider` implemented to serve cases and debtors.
- UI Screens built: `CasesScreen` (data table view), `CaseDetailScreen` (3-tab view: Overview, Timeline & History, Financials).
- Dialogs: `CaseFormDialog` (with debtor quick-create), `DebtorFormDialog`, `ReassignCaseDialog`, `CloseCaseDialog`.
- Reassign and Close logic wrapped in specific permission checks.
- Visual pass integrated: `AppTypography` and `AppColors` fully adopted.

### Completion criteria met
- [x] Create a Debtor (masking verified via code logic)
- [x] Create a Case (auto-generates CASE-2026-00000X)
- [x] Reassign a case and log it
- [x] Case timeline shows assignments and status changes
- [x] 'Outstanding' computed live

---

## PHASE 3B — Recovery Assignments (Case Pools) ✅

**Completed:** 2026-08-26  
**Status:** ✅ Done — `dart analyze` clean for Phase 3B files (9 pre-existing infos only); `flutter test` 7/7 green.

### What was built

#### Database Schema (`lib/database/schema.dart` + `lib/database/database_helper.dart`)
- Schema version bumped **7 → 8**.
- New synced tables:
  - `recovery_assignments` — `id PK, assigned_employee_id, assigned_by, target_amount, start_date, deadline_date, status (DEFAULT 'Active'), notes`.
  - `case_assignment_batch_history` — `id PK, recovery_assignment_id, case_id, added_date, removed_date` (membership / time-in-pool ledger).
- Indexes: `idx_case_assignment_batch_history_assignment_id`, `idx_case_assignment_batch_history_case_id`, `idx_recovery_assignments_employee_id`.
- Added to **both** `createAllTables` (fresh/test DBs) and `onUpgrade` (`if (oldVersion < 8)`).
- `assigned_employee_id` stores a **user id** (consistent with `cases.primary_owner_id` / `case_assignments.assigned_to_employee_id`).

#### Sync Registration (`lib/sync/sync_constants.dart`)
- `recovery_assignments` and `case_assignment_batch_history` appended to `kSyncedTables` (both carry the shared `Sync*` audit trail columns).

#### Model (`lib/models/recovery_assignment_model.dart`)
- `RecoveryAssignmentModel` — `toMap`/`fromMap`/`copyWith`; computed `isOverdue` (`deadlineDate.isBefore(DateTime.now())`) and `isActive`.
- `RecoveryAssignmentBatchHistoryModel` — `toMap`/`fromMap`/`copyWith`; `isPresent` (added, not yet removed).
- Pure Dart, no Flutter/SQLite imports.

#### Repository (`lib/repositories/recovery_assignment_repository.dart`)
- `extends BaseRepository`; permission enforced per-method (`assignment.*`), no wildcards. Super Admins bypass all checks via `AuthSession.hasPermission`.
- `create(assignment, caseIds)` — **active-batch guard** (a case may belong to at most one active batch; throws otherwise); inserts assignment + batch_history members + `audit_logs` in a transaction.
- `getById` — **Recovery-Officer ownership guard** (officers may only load their own batches; Managers/Directors/Execs/SuperAdmin may view any).
- `getByEmployee` — row-scoped list for the officer picker detail.
- `getByClient` — manager scope: active batches whose pooled cases belong to a client org.
- `getAssignmentCases`, `getCaseAddedDate`, `listRecoveryOfficers` (users JOIN roles WHERE `roles.name='Recovery Officer'`).
- `updateStatus` — rejects the read-time `'Overdue'` value (computed only). `removeCaseFromBatch` — soft-removes a member (sets `removed_date`) + audit.

#### Seeds (`lib/database/seeds.dart`)
- New permissions (category `'assignments'`): `assignment.view`, `assignment.create`, `assignment.edit`, `assignment.delete`.
- Role grants:
  | Role | view | create | edit | delete |
  |------|------|--------|------|--------|
  | Executive / Director | ✅ | ✅ | ✅ | ✅ |
  | Manager | ✅ | ✅ | ✅ | ✅ |
  | Case Manager | ✅ | ✅ | ✅ | ✅ |
  | Recovery Officer | ✅ | ❌ | ❌ | ❌ |
  | (others) | ❌ | ❌ | ❌ | ❌ |
- Super Admin auto-granted all four (existing `assignPerms(superAdminId, all)`).
- **Seeded test-only Recovery Officer** user `sam.mugisha` / `Agent@1234` (role: Recovery Officer, `is_active=1`). Used by the Phase 3B tests only — **not** a real account and must be rotated/removed before production seeding.

#### Provider (`lib/providers/recovery_provider.dart`)
- Constructor now `RecoveryProvider(caseRepo, debtorRepo, recoveryAssignmentRepo)`; `additionalRepos` propagated through `AuthRepository` in `main.dart`, `debtors_ui_test.dart`, and `recovery_flow_test.dart` so `login()` sets the session on the new repo.
- Added: `createRecoveryAssignment` (returns the new id; auto-suggests target from pooled cases), `loadRecoveryAssignment` (detail + cached `added_date`/`case_status_history` per pooled case), `loadAssignmentsForEmployee` (row scope), `loadAssignmentsForClient`, `loadOfficers`, `completeAssignment`, `cancelAssignment`, `removeCaseFromBatch`.
- Getters: `recoveryAssignments`, `currentAssignment`, `currentAssignmentCases`, `officers`, `hasCurrentAssignment`.
- Computed: `currentAssignmentRecoveredAmount` (0.0 until Phase 5 payments), `timeToRecoveryForCase` (resolved−added when closed; now−added while in-progress).

#### UI
- `lib/screens/recovery/recovery_assignment_form.dart` — Create-as-modal (`AlertDialog` + `Form`): officer dropdown (`listRecoveryOfficers`), case multi-select (`CheckboxListTile` over open cases), auto-suggested target editable, deadline date-picker, optional notes. Target auto-suggests from Σ `CaseModel.outstandingAmount`; stops auto-updating once the user edits.
- `lib/screens/recovery/recovery_assignment_detail_screen.dart` — detail view: target vs. recovered stat cards + LinearProgress, deadline vs. today (`isOverdue` chip), active-batch actions (Complete / Cancel / Remove case from pool), pooled-cases table with `timeToRecoveryForCase` per case.
- Wiring: `CasesScreen` header gained a **Create Batch** button (opens the form); `onAssignmentCreated(id)` bubbles up to `AppShell`, which routes to `RecoveryAssignmentDetailScreen` via `_selectedAssignmentId` (mirrors the existing `_selectedCaseId` detail routing). `main.dart` provider wiring updated.

### Tests
- `test/recovery_flow_test.dart` — **Phase 3B integration test**: Super Admin pools Acme's seeded case + a 2nd created case into a batch for the seeded officer; asserts 2 `case_assignment_batch_history` rows, target = Σ outstanding, `audit_logs` `assignment.create`, row-scoping (`getByEmployee` → 1), `currentAssignmentRecoveredAmount == 0.0`, in-progress `timeToRecoveryForCase > 0`, and the **active-batch guard** rejects reusing a case.
- `test/debtors_ui_test.dart` — **widget test**: empty `RecoveryAssignmentForm` submission shows all 4 validation errors (officer / case / target / deadline). `autoLoad:false` keeps it off the FFI-backed repository.
- Full suite: **7/7 green** (`flutter test` EXITCODE=0; the 5 original tests remain green + 2 new). `dart analyze lib test` clean for all Phase 3B files.

### Known gaps / forward hooks
- `RecoveryAssignmentForm`/`DetailScreen` are not click-tested end-to-end (headless harness). The data layer is verified via the integration test; the form is verified for validation via widget test.
- No dedicated "Recovery Assignments" list route in the sidebar yet; a batch is reachable via CasesScreen → Create Batch → detail. A full officer/manager batch list is a small follow-up.
- `target_amount` auto-suggest uses `CaseModel.outstandingAmount` (`= totalClaim` until Phase 5 introduces verified payments / adjustments).

---

## PHASE 4 — Tasks, Activities, Calendar ⬜
## PHASE 5 — Payments, Promises, Financial Integrity ⬜
## PHASE 6 — Documents, SLA, Aging ⬜
## PHASE 7 — KPI Engine, Employee & Team Performance ⬜
## PHASE 8 — Dashboards, Reports, Alerts ⬜
## PHASE 9 — Hardening, Bulk Import, Final Test ⬜
## PHASE 10 — Supabase Cloud Backend (FUTURE) ⬜
## PHASE 11 — Offline-Resilient Cloud Sync (FUTURE, if needed) ⬜

