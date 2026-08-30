# RECOVERA — Phase 0 + Phase 1 (paste everything in the box below into Antigravity as one prompt)

This is the complete foundation prompt: architecture rules + the full LAN networking mechanism (not just "a sync engine" — every piece needed for two PCs on the same office network to actually find each other, authenticate, and share data) + auth/roles + navigation shell. Nothing here is optional or a placeholder except where explicitly marked.

---

```
You are building RECOVERA, a Client, Case & Recovery Management Platform for
a company that recovers unpaid money on behalf of corporate clients (example:
a telecom client paid an agent/vendor who then failed to deliver, and Recovera's
company is hired to recover the money from that debtor).

====================================================================
PART A — NON-NEGOTIABLE ARCHITECTURE
====================================================================

TECH STACK (fixed — do not substitute):
- Flutter, targeting Windows desktop
- State management: Provider
- Local database: sqflite_common_ffi (SQLite)
- LAN networking: shelf + shelf_router (HTTP server), bonsoir (mDNS discovery),
  http (client requests)
- Fonts: Google Fonts Inter. Custom title bar via bitsdojo_window — scaffold
  once, do not touch window-chrome code afterward.
- Windows toast notifications via local_notifier (not needed until later
  phases, but note it as a fixed dependency).

DATA ACCESS RULE:
- Every screen, Provider, and future business-logic module (KPI engine,
  reports, etc.) talks ONLY to a Repository layer (e.g. `CaseRepository`,
  `UserRepository`) — never to SQLite queries directly. The Repository is
  the only thing that knows how a record is actually stored and fetched.
- The app always reads and writes its own LOCAL SQLite database, full stop —
  this never changes in any future phase, including if a cloud backend is
  added later. What changes over time is only how that local data gets
  replicated to other machines.
- Every table has UUID primary keys (not auto-increment integers) and four
  sync columns from day one: SyncCreatedAt, SyncUpdatedAt, IsDeleted,
  DeletedAt.
- Permissions are enforced in the data-access/service layer, not just the
  UI. A lower-privileged account attempting an action it doesn't have must
  be rejected by the Repository itself, even if that action were somehow
  triggered outside the normal UI — never rely on a button simply being
  hidden.
- Financial records are never hard-deleted (relevant from Phase 5 onward,
  but keep this in mind architecturally now: no destructive delete methods
  on any repository that will hold money-related data later).

====================================================================
PART B — THE LAN NETWORKING MECHANISM (build this exactly, file by file)
====================================================================

GOAL: any PC on the same office network can either become the authoritative
"Master" (first one to launch) or discover and join an existing Master as a
"Worker," authenticate with a shared office key, and exchange data changes
automatically. This entire section is a proven pattern adapted from a
working sister application — build it as specified, don't redesign it.

--- File: lib/sync/sync_constants.dart ---
Define:
- SERVER_PORT (pick a fixed port, e.g. 47474)
- Endpoint path constants: ENDPOINT_HEALTH ("/health"), ENDPOINT_SYNC_PULL
  ("/sync/pull"), ENDPOINT_SYNC_PUSH ("/sync/push"), ENDPOINT_ROLE_INFO
  ("/role"), ENDPOINT_KEY_CHECK ("/key-check")
- HEARTBEAT_INTERVAL_SECONDS (e.g. 10) and SYNC_INTERVAL_SECONDS (e.g. 15)
- ROLE_MASTER, ROLE_WORKER string constants

--- File: lib/sync/sync_models.dart ---
- `enum NetworkRole { master, worker, unassigned }` (no "secondary" role for
  Recovera v1 — that's a HarvestSync-specific concept, skip it)
- `enum SyncStatus { connected, syncing, offline, discovering, keyMismatch }`
- `enum PingResult { online, offline, keyMismatch }`
- `class DeviceInfo` (immutable): deviceID, deviceName, role, ipAddress,
  lastSeenAt, with an `isOnline` getter (true if lastSeenAt within ~15
  seconds) and toJson/fromJson
- `class SyncPushPayload`: deviceID, officeKey, tableName, records (List of
  Map), pushedAt — with toJson/fromJson

--- File: lib/sync/sync_discovery.dart ---
Using bonsoir:
- `startBroadcasting({required int port})` — Master calls this to advertise
  itself on mDNS so Workers can find it
- `stopBroadcasting()`
- `startDiscovering()` — begins a continuous mDNS listener (safe to call
  repeatedly without duplicating listeners)
- `stopDiscovery()`
- expose `latestMasterIP` (the most recently discovered Master's IP, or
  null) and `waitForMaster({Duration timeout = const Duration(seconds: 10)})`
  which returns the IP once found or null on timeout

--- File: lib/sync/sync_server.dart ---
`class SyncServer` — runs only on the device acting as Master.
- `start(String officeKey)`: builds a shelf_router with these routes:
  - GET /health → returns JSON: status "ok", role "master", a truncated
    hash of the office key (never the raw key) for display purposes
  - GET /sync/pull?table=X&since=<ISO timestamp> → validates the
    X-Office-Key header against officeKey; queries local SQLite for rows in
    table X where SyncUpdatedAt > since; returns them as JSON. If the query
    fails because the table is missing SyncUpdatedAt (schema gap mid-
    migration), return an empty JSON array instead of a 500 error — this
    prevents the caller entering an infinite retry loop.
  - POST /sync/push → validates the key header; parses the body as a
    SyncPushPayload; for each record, calls the conflict resolver (see
    below) to merge it into local SQLite; returns a count of records
    processed
  - GET /role → returns { role: "master", port: SERVER_PORT }
  - POST /key-check → body contains a candidate key; returns
    { valid: true/false } by comparing against officeKey — used by Workers
    to detect a rotated key without a full sync attempt
- On Windows, after starting, run `netsh advfirewall firewall add rule` to
  open the chosen port for inbound TCP — wrap in try/catch, non-fatal if it
  fails (user may need to allow it manually via a Windows prompt)
- `stop()` — closes the server
- Every route except /health and /key-check must reject requests where the
  X-Office-Key header doesn't match, returning 401

--- File: lib/sync/sync_client.dart ---
`class SyncClient` — used by a device acting as Worker (or by Master to
verify its own server is responding).
- `configure({required String masterIP, required String officeKey,
  required String deviceID})`
- `pingMasterWithResult()` → returns PingResult by calling POST /key-check;
  distinguishes "unreachable" (network error/timeout) from "reachable but
  key rejected" (valid: false in response) — this distinction matters, don't
  collapse both into a single "offline" state
- `pullDeltaTable(String tableName, String sinceTimestamp)` → GET
  /sync/pull, returns parsed records or null on failure
- `pushDeltaRecords({required String tableName, required
  List<Map<String,dynamic>> records})` → POST /sync/push, returns success
  bool
- `executeDeltaSyncExchange(List<String> tableNames)`: for each table —
  1. read this table's last-synced watermark from a local `sync_state`
     table (columns: TableName, LastSyncedUpdatedAt) — default to
     '1970-01-01 00:00:00' if never synced
  2. pull incoming changes since that watermark, resolve+upsert each via
     the conflict resolver (below)
  3. query local rows where SyncUpdatedAt > watermark, push them
  4. update the watermark to the timestamp captured at the START of this
     exchange (not the end) — this avoids missing records that changed
     during the exchange itself

--- File: lib/sync/lock_engine.dart ---
`class LockEngine` — prevents two devices editing the same record at once.
- Backed by a local `distributed_locks` table (NOT synced — this is
  intentionally device-local/ephemeral state; if replicated, a lock held on
  one device would incorrectly block editing on another that never
  requested it)
- `acquireLock({required String entityType, required String entityId,
  String lockMode = 'edit'})` → returns an enum result (acquired / denied /
  alreadyHeldBySelf)
- `releaseLock(String entityType, String entityId)`
- Give each device/role a priority score (e.g. Manager/Admin roles can
  break a lock held by a lower-priority role in a genuine conflict — keep
  this simple for v1, don't over-engineer priority rules)
- `getActiveLocks()` — for an admin-visible list of what's currently locked
  and by whom
- `forceBreakLock(String lockId)` — admin action to clear one stuck lock
- `forceBreakAllLocks()` — admin action ("Force Sync Flush" style button)
  to clear every lock, for when a device disconnected mid-edit and left
  something stuck
- Run a periodic heartbeat/cleanup that auto-expires locks whose holder
  hasn't renewed them in some window (e.g. 30 seconds), so a crashed device
  doesn't permanently block a record

--- File: lib/sync/sync_conflict_resolver.dart ---
This is the exact proven logic from the reference implementation, adapted
for Recovera's uniform UUID schema (every table uses a single `id` column
as its primary key — no per-table key-name map needed, unlike the source
system where PK column names vary by table).

`class SyncConflictResolver`:
- `resolveAndUpsert({required db, required String tableName, required
  Map<String,dynamic> incomingRecord, required String sourceDeviceID,
  required String currentDeviceRole})`:
  1. Look up the existing local row by `id == incomingRecord['id']`.
  2. If no local row exists, insert the incoming record as-is
     (`ConflictAlgorithm.replace`).
  3. If a local row exists, compare `SyncUpdatedAt` on both:
     - If either side's timestamp is missing or fails to parse, fail open:
       accept and write the incoming record without comparison (don't block
       sync over a malformed timestamp).
     - If incoming is NEWER than existing → update the local row with the
       incoming record.
     - If incoming is OLDER than existing → do nothing to the local row,
       but write a row to a `sync_conflicts` table (columns: table_name,
       record_id [TEXT, not int — every id in this schema is a UUID
       string], winner_device_id, loser_device_id, winner_updated_at,
       loser_updated_at, resolved_at). Log the ACTUAL winning device's id
       (whichever device's data was kept), not a hardcoded "master" — this
       matters for Recovera since the audit/KPI system depends on accurate
       actor attribution throughout, unlike a simple label in a rarely-read
       log table.
     - If both timestamps are exactly equal, do nothing at all — no write,
       no conflict log entry. This is intentional, not a gap to fill in.
  4. Wrap each insert/update in try/catch so one bad record doesn't abort
     the whole sync batch — but unlike simply swallowing the error, log it
     (debugPrint or equivalent) so failures are visible during development
     and support, rather than fully silent.

--- File: lib/sync/lan_sync_adapter.dart ---
Implements the app's `SyncAdapter` interface (pushChanges, pullChanges,
getConnectionStatus) by orchestrating everything above:
- `initialize({required String deviceID, required String deviceName})`:
  loads persisted network config (role, office key, master IP if known)
  from local SQLite; if none exists, this is first launch
- First-launch bootstrap: if no Master is found on the LAN after a
  reasonable discovery window, this device becomes Master (starts
  SyncServer, starts mDNS broadcasting, creates fresh local DB); otherwise
  it becomes a Worker (configures SyncClient with the discovered Master's
  IP)
- Worker mode: on connect, start a heartbeat timer (ping every
  HEARTBEAT_INTERVAL_SECONDS) and a sync timer (executeDeltaSyncExchange
  every SYNC_INTERVAL_SECONDS)
- Heartbeat failure handling: after 2 consecutive missed heartbeats, mark
  status offline and check whether the Master reappeared under a new IP
  (mDNS may have picked up a change); if a key-mismatch is detected at any
  point, stop timers immediately and surface a distinct "keyMismatch"
  status so the UI can prompt for a new key rather than retrying blindly
- `applyNewOfficeKey(String newKey)`: reconfigures the client and re-runs
  discovery — used after a user re-enters a rotated key
- Expose a manual-IP fallback: if mDNS discovery fails, allow a user to
  type in the Master's LAN IP directly and attempt to connect

--- File: lib/providers/sync_provider.dart ---
Wraps LanSyncAdapter in a ChangeNotifier-based Provider. Exposes: role,
status, localIpAddress, availableIPs (network interfaces on this machine,
so a Master can choose which one to broadcast on if there are several),
connectedDevices (list of Workers seen recently, for Master to display),
lastSyncTime, isBroadcasting. Methods: scanForMasterNetwork(),
connectToMasterIP(String), rotateOfficeKey(), forceSyncFlush(),
disconnectDevice(String deviceId), assignRole (if you want manual role
override — optional for v1, skip if it adds complexity).

--- File: lib/screens/network_setup_screen.dart ---
Admin-only screen with:
- If this device is Master: a card showing which network interface it's
  broadcasting on (with a way to pick a different one if multiple exist),
  and current status (offline / broadcasting-no-workers / workers connected)
- If this device is Worker: a "Scan for Master" button, falling back to a
  manual IP entry field if discovery fails
- A list of connected devices with online/offline indicator (based on
  DeviceInfo.isOnline) and a "Disconnect" action per device
- The office key displayed (with copy button) and a "Change Key" action
  that warns this will disconnect every other device immediately
- A "Force Sync Flush" button (calls forceBreakAllLocks) for clearing
  stuck locks, with a confirmation dialog since it's a disruptive action

====================================================================
PART C — DATABASE SCHEMA (Phase 1 scope)
====================================================================

Tables, all with id (UUID), SyncCreatedAt, SyncUpdatedAt, IsDeleted,
DeletedAt:
- users (username, password_hash, password_salt, employee_id, role_id,
  is_active, last_login)
- employees (first_name, last_name, email, phone, department_id, team_id,
  job_title)
- roles (name, description)
- permissions (code, name, description, category)
- role_permissions (role_id, permission_id)
- departments (name, description)
- teams (name, department_id, leader_employee_id)
- audit_logs (user_id, action, entity_type, entity_id, old_value,
  new_value, timestamp) — append-only, no update/delete methods on its
  repository
- network_config (device_id, network_role, office_key, coop_... wait, use
  office_name, master_ip) — local device settings, not itself synced
- sync_state (table_name, last_synced_updated_at) — local per-table
  watermark, not itself synced
- distributed_locks (entity_type, entity_id, device_id, device_name, mode,
  acquired_at, expires_at) — local/ephemeral, not synced
- sync_conflicts (table_name, record_id [TEXT], winner_device_id,
  loser_device_id, winner_updated_at, loser_updated_at, resolved_at) —
  local/ephemeral, not synced; written by sync_conflict_resolver.dart
  whenever an incoming update is discarded for being older than the local
  version

Seed roles: Super Administrator, Executive/Director, Manager, Case Manager,
Recovery Officer, Business Development Officer, Finance Officer, Auditor
(read-only).

Seed example permissions: user.create, user.edit, user.delete, user.view,
role.assign, role.view, kpi.configure, kpi.view, audit.view, settings.edit.

====================================================================
PART D — AUTH, PROVIDERS, UI SHELL
====================================================================

- Password hashing: PBKDF2 with at least 100,000 iterations and a random
  salt per user (not 10,000 — that's too low for current standards). No
  plaintext passwords anywhere, including logs.
- `AuthRepository`: login(username, password) → AuthSession or throws;
  logout(); getCurrentSession(). Logs login/logout to audit_logs.
- `AuthSession` model: userId, username, roleId, permissions (a Set of
  permission codes), loginTime, with hasPermission(code) → bool.
- `AuthProvider`: wraps AuthRepository, exposes currentSession, isLoggedIn,
  hasPermission(code).
- main.dart: initializes sqflite_common_ffi, runs schema migrations, seeds
  roles/permissions, sets up the Provider tree, wraps the app in
  bitsdojo_window's window chrome.
- login_screen.dart: username + password fields, error messages for wrong
  credentials or disabled account, no "remember me" in v1.
- app_shell.dart: custom title bar, left sidebar, body area (IndexedStack
  or Navigator).
- sidebar.dart: sections below, each item's visibility driven by
  hasPermission(code) — but remember, the REAL enforcement is in the
  Repository layer, this is just what's convenient to show:
  Dashboard | CRM (Leads, Clients, Contacts) | Recovery (Cases, Debtors,
  Payments, Promises) | Work (Tasks, Activities, Calendar) | Performance
  (Performance Center, Employee Performance, Team Performance) | Documents
  | Reports | Organization (Employees, Teams) | Administration (Users,
  Roles, Audit Log, Network Setup, Settings)
- One placeholder screen per nav item: centered Text("Coming in Phase N") —
  no fake data, no stub buttons that look functional but aren't.

====================================================================
PART E — VERIFICATION (do all of this before calling Phase 1 done)
====================================================================

1. Create two user accounts with different roles (e.g. Super Administrator
   and Recovery Officer). Log in as each — confirm the sidebar differs.
2. As the Recovery Officer account, attempt an action that role shouldn't
   have (e.g. call UserRepository.createUser() or attempt to reach the
   Network Setup screen). It must be rejected by the Repository/data-access
   layer itself — not merely hidden from the sidebar.
3. Confirm audit_logs records login and logout events with correct
   timestamps and user IDs, visible on the Audit Log screen as admin.
4. Run the app on two separate Windows machines on the same office network
   (or two VMs bridged onto the same virtual network). Confirm: the first
   one launched becomes Master and shows "broadcasting" status; the second
   discovers it via mDNS, prompts for the office key, and connects; the
   Master's Connected Devices list shows the Worker as online.
5. Create a test record (e.g. a department) on the Worker while both are
   running. Wait one sync interval. Confirm it now exists in the Master's
   database too, and vice versa when created on Master.
6. Stop the Worker app, change the office key on the Master via the Change
   Key action, restart the Worker. Confirm it shows a key-mismatch state
   and requires the new key to reconnect — not a silent failure.
7. Manually create a row-level lock scenario if feasible (or verify the
   lock acquire/release methods work via a temporary test button) — full
   lock-contention UI isn't needed until Phase 3 (cases), but the
   LockEngine itself must be functional and tested now, since Phase 3
   depends on it.

Confirm you understand this whole document, then begin building.
```
