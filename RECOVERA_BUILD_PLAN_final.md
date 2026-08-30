# RECOVERA — Phased Build Plan for Google Gemini Antigravity

## How to use this document

Do **not** paste this whole file into Antigravity at once. Paste **one phase at a time**, in order. After each phase, open the app, click through what was built, and confirm it actually works before you paste the next phase. If a phase doesn't compile or a feature is faked, stop and fix it before moving on — don't let the next phase build on top of a broken one.

Each phase below is written so you can copy it directly as a prompt. Phase 0 (architecture) should be pasted first and re-pasted as context at the start of every later phase, since Antigravity won't remember earlier sessions.

---

## PHASE 0 — Architecture Decisions (paste this at the start of every phase)

```
You are building RECOVERA, a Client, Case & Recovery Management Platform for
a company that recovers unpaid money on behalf of corporate clients (example:
a telecom client paid an agent/vendor who then failed to deliver, and Recovera's
company is hired to recover the money from that debtor).

TECH STACK (fixed — do not substitute):
- Flutter, targeting Windows desktop
- State management: Provider
- Local database: sqflite_common_ffi (SQLite)
- Multi-user on one office LAN, for now: one PC acts as MASTER (holds the
  authoritative database and runs a small local HTTP server), other employee
  PCs act as WORKERS that discover the Master via mDNS (bonsoir package) and
  sync over HTTP. This mirrors an existing production system (HarvestSync) —
  same pattern, new schema. Specifically, reuse this proven design exactly:
  - Master HTTP server built on `shelf` + `shelf_router` (not raw `HttpServer`
    with manual routing). Endpoints: health check, delta pull
    (`GET ?table=X&since=<timestamp>`), delta push (`POST` a batch of changed
    records for one table), a key-check endpoint, and a role-info endpoint.
  - Every request authenticated via a shared secret sent as a custom header
    (call it `X-Office-Key` for Recovera). This key is also what gates which
    devices may join the LAN network at all — it is entered once per device
    and can be rotated by an admin, which immediately disconnects every
    other device until they re-enter the new key.
  - Each table has SyncCreatedAt, SyncUpdatedAt, IsDeleted, DeletedAt columns.
    Sync progress is tracked **per table**, not one global timestamp — store
    a `sync_state` table (TableName, LastSyncedUpdatedAt) so each table
    catches up independently and progress survives an app restart.
  - Conflict handling is TWO separate mechanisms, not one — do not collapse
    these into a single "last write wins" rule:
    1. Live edit locking: before editing a record (a case, a payment, etc.),
       a device must acquire a row-level lock on it. Include role-based
       priority for resolving lock disputes, and an admin "force-clear all
       locks" action for when a device disconnects mid-edit and leaves a
       stuck lock behind.
    2. Replication-time conflict resolution: when pulling/pushing during a
       sync exchange, incoming records are merged through a dedicated
       resolver — never a blind overwrite of one side by the other. Ask me
       for the exact merge rule when you reach this step if it isn't already
       clear from context.
  - On Master startup (Windows only), automatically add a Windows Firewall
    inbound rule allowing the sync port, using `netsh advfirewall`.
  - A delta-pull request for a table that's missing its sync column (e.g.
    mid-migration) should return an empty result, not a server error — this
    avoids the client entering an infinite retry loop during a schema
    upgrade.
  - Sync-eligible tables are an explicit allow-list, documented with reasons
    for any exclusion — e.g. a computed/cached value (Recovera's `Outstanding`
    is exactly this: derive it locally from synced claim/payment data, don't
    sync it as its own column) or device-local ephemeral state (active locks,
    unsaved drafts) should never be synced.
- IMPORTANT — Recovera is a local-first application whose business logic
  must be independent of its persistence and synchronization backend.
  Version 1 uses SQLite + LAN Master/Worker sync. A later version will add
  Supabase as a cloud backend. To make that possible without a rewrite:
  - Every screen, Provider, and the KPI engine talks ONLY to a Repository
    layer (e.g. `CaseRepository`, `TaskRepository`, `PaymentRepository`) —
    never to SQLite queries directly. The Repository is the only place that
    knows how a Case or Payment is actually stored and fetched.
  - The app always reads and writes its own **local** SQLite database,
    full stop — this never changes, in any future phase. What changes over
    time is only how that local data gets replicated elsewhere.
  - Replication is handled by a single, separate `SyncAdapter` interface
    (`pushChanges()`, `pullChanges(since)`, `getConnectionStatus()`), kept
    completely apart from the Repository layer. Build one implementation now:
    `LanSyncAdapter`, using the mDNS/Master-Worker approach below.
  - Only ONE SyncAdapter implementation is ever active at a time. When a
    future phase adds `SupabaseSyncAdapter`, it replaces `LanSyncAdapter` —
    they do not run simultaneously, and they do not sync to each other. This
    is intentional: running two live sync layers against each other is a
    real source of data conflicts, and swapping the adapter avoids that
    problem entirely rather than needing to solve it later.
  - The Master PC's database is the **authoritative replica for LAN sync in
    V1 only** — not a permanent architectural dependency. When Supabase
    arrives, authority moves to the cloud database, and the Master/Worker
    concept goes away entirely (see Phase 10). Don't design anything as if
    "the Master PC" is a permanent fact of the system.
  - Workers must reach case/task/payment/etc. data ONLY through
    `Repository → local SQLite → LanSyncAdapter → Master`. A Worker must
    never make an ad hoc HTTP call directly into the Master's database
    outside that path — every read and write, on Master or Worker, goes
    through the same Repository layer.
  - Do not hard-code LAN-specific assumptions (like "Master PC always
    reachable on the local subnet") anywhere outside `LanSyncAdapter`.
- Fonts: Google Fonts Inter. Custom title bar via bitsdojo_window — do not
  touch window-chrome code once scaffolded.
- Windows toast notifications via local_notifier.
- Licensing: integrate the existing Elvium HMAC-SHA256 + RSA licensing system
  (Master PC activation via .hslicense file, Worker PC activation via LAN
  token, 5-day offline grace period). Ask me for the existing licensing module
  if you need it — do not build a new licensing scheme from scratch.

NON-NEGOTIABLE PRINCIPLES:
1. Every KPI number shown anywhere in the app must be calculated from real
   rows in the database (COUNT, SUM, ratio queries) — never a manually typed
   or hard-coded number, except clearly-labeled demo seed data.
2. Every KPI number must be clickable and open the exact underlying records
   (tasks, calls, payments) that produced it. Summary → Detail → Evidence,
   everywhere, no exceptions.
3. Every button you build must actually work. No placeholder charts, fake
   search, fake notifications, or dead-end forms.
4. Financial records are never hard-deleted. A wrong payment gets a reversal
   transaction, not a delete. A closed case is locked until reopened with a
   logged reason.
5. Do not build ahead of the current phase. Wait for the next phase's prompt
   before adding features from later phases, even if they seem related.
6. Permission seeding is a required step of EVERY phase, not a one-time fix —
   this applies from this point forward through every remaining phase, not
   just the one that happened to expose the bug. Whenever a phase introduces
   a new permission code (e.g. debtor.view in Phase 3, kpi.configure in
   Phase 7, etc.), immediately add role_permissions rows for every role that
   should reasonably have it — not just the one role the feature was built
   for. Super Administrator must never depend on seeded rows at all: it
   should bypass permission checks entirely (treat it as having every
   permission by definition), so this class of bug can't recur for that
   role specifically. For every other role, as part of that phase's
   verification step, show the current full role → permission matrix so
   gaps are caught immediately, not discovered later as a runtime error.
   If a Roles management screen exists (Administration → Roles), it must
   read the permissions table dynamically, not from a hardcoded list — so
   new permissions added in any future phase appear there automatically
   with zero rework needed on that screen.
7. Sync-table registration is a required step of EVERY phase, same as
   permission seeding above — this was found missing for Phase 2 and 3
   tables and must not recur. Whenever a phase creates a new table meant to
   replicate between devices, it MUST be added to the sync-eligible table
   list (kSyncedTables or equivalent) as part of that same phase, not left
   for later. If a table is intentionally local-only (ephemeral device
   state, computed caches), document why in a comment next to the
   exclusion, per the existing convention. As part of every phase's
   verification from now on, run an actual two-machine sync test on every
   NEW table introduced that phase — confirm a record created on one device
   actually appears on the other after a sync interval, not just that the
   table exists in the schema.

Confirm you understand these principles, then begin the phase described below.
```

---

## PHASE 1 — Foundation: DB, Auth, Roles, Navigation Shell

**Goal:** an app that launches on Windows, has a login screen, distinguishes roles, and has an empty but navigable sidebar. No business features yet.

Steps for Antigravity to follow, in order:

1. Scaffold the Flutter Windows project with Provider, sqflite_common_ffi, bitsdojo_window (custom title bar), Google Fonts Inter.
2. Create the SQLite schema for: `users`, `employees`, `roles`, `permissions`, `role_permissions`, `departments`, `teams`. Use UUID primary keys, not auto-increment integers. Add `SyncCreatedAt`, `SyncUpdatedAt`, `IsDeleted`, `DeletedAt` to every table from day one — this is required by the LAN sync design and is painful to retrofit later (this exact retrofit has caused real bugs in a sister project).
3. Seed these roles with permission sets, matching what's described in Phase 0's context: Super Administrator, Executive/Director, Manager, Case Manager, Recovery Officer, Business Development Officer, Finance Officer, Auditor (read-only).
4. Build password hashing (salted, e.g. PBKDF2 or bcrypt-equivalent available in Flutter/Dart) and a login screen. No plaintext passwords anywhere, including logs.
5. Build the Master/Worker bootstrap flow behind `LanSyncAdapter`, per the architecture in Phase 0: first PC to run the app becomes Master (starts the shelf server, registers mDNS, adds the firewall rule, creates the DB) and subsequent PCs discover it via mDNS, enter the shared office key, and register as Workers. This exact pattern is already proven in a sister project (HarvestSync) — reuse its discovery/health-check/lock-engine code directly rather than redesigning it, adapting only table names and the key header name. Don't let any of this logic leak outside `LanSyncAdapter`. Note: worker device registration in the reference implementation is bundled with license enforcement (device fingerprint, max-device limit) — for Phase 1, build plain LAN join (office key only, no license check yet); the license-bound version of registration is added in Phase 9 when the Elvium licensing module is integrated.
6. Build the main app shell: sidebar with the sections below (leave each as an empty placeholder screen for now — do not stub with fake data):
   `Dashboard | CRM (Leads, Clients, Contacts) | Recovery (Cases, Debtors, Payments, Promises) | Work (Tasks, Activities, Calendar) | Performance (Performance Center, Employee Performance, Team Performance) | Documents | Reports | Organization (Employees, Teams) | Administration (Users, Roles, Audit Log, Settings)`
7. Enforce permissions in the data-access/service layer, not a web server (this is a local desktop app) — but never rely on hiding UI elements alone. A Recovery Officer account must be rejected by the data-access layer itself if it attempts an admin-only action, even if that action were somehow triggered outside the normal UI.
8. Build the append-only `audit_logs` table and log at minimum: login, logout, user creation, permission change.

**Before moving to Phase 2:** confirm you can create at least two user accounts with different roles, log in as each, and see that the sidebar and available actions differ correctly. Then deliberately try to break it: as the lower-privileged account, attempt an action that role shouldn't have (e.g. a Recovery Officer trying to change KPI configuration or another employee's role) — it must be rejected by the data-access layer itself, not merely absent from the UI. If it's only missing from the UI and not actually blocked underneath, permissions aren't built correctly yet.

---

## PHASE 2 — CRM: Leads, Clients, Contacts

**Goal:** track prospective and existing clients, their contacts, and what was discussed/decided with each.

1. Create tables: `organizations` (this is the CLIENT — the company that hires Recovera, e.g. a telecom), `contacts` (a specific person at that client — e.g. their Finance Manager), `leads`, `opportunities`. Do not merge organizations and contacts into one table.
2. Client fields: company name, registration number, industry, address, phone, email, status (Prospect → Contacted → Negotiating → Onboarding → Active → Dormant → Suspended → Lost → Closed), account manager (an employee), date acquired, lead source, contract dates, notes.
3. Contact fields: name, position, phone, email, preferred channel, role (Primary/Finance/Legal/Operations/Executive/Other), decision-maker flag, notes, last interaction date, next follow-up date. Unlimited contacts per client.
4. Lead pipeline as a Kanban board: New → Qualified → Contacted → Meeting → Proposal → Negotiation → Contract → Onboarding → Client. Each lead has an owner, source, expected value, next action, follow-up date.
5. Every interaction with a lead or contact (call, meeting, note, decision made) must be logged as an **activity** tied to that lead/contact and to the employee who logged it — this is what "what we spoke about and decided" resolves to later. Do not add a separate freeform "notes" field that bypasses activity logging; the activity log is the single source of truth.
6. Build a Client detail page with tabs: Overview, Contacts, Activities/Timeline, (leave Cases/Financial/Performance tabs as placeholders — built in later phases).
7. Global search across clients and contacts (partial match on name/company/phone/email).

**Before moving to Phase 3:** confirm you can create a client, add contacts to it, log an activity against a contact, move a lead through the pipeline, and see it all reflected on the client's timeline.

---

## PHASE 3 — Cases, Debtors, Assignment

**Goal:** the actual recovery matters — the reason the business exists.

1. Create tables: `debtors` (the person/company money is being recovered FROM — never confuse with `organizations`/clients), `cases`, `case_types`, `case_statuses`, `case_assignments`, `case_status_history`.
2. Case gets an auto-generated readable ID like `CASE-2026-000001`. Fields: client, client reference, title, case type, description, priority, status, primary owner (employee), supervisor, supporting employees, date received, deadline, date closed.
3. Debtor fields: name, type (Individual/Company/Agent/Employee/Supplier/etc.), phone, email, address, employer/business, notes. Mark clearly which debtor fields are sensitive and gate them by permission (per Phase 0 principle — this data is personal information under Rwandan data-protection rules, treat it accordingly).
4. Financial fields on a case: principal, interest, penalties, fees, settlement amount, total claim. **Outstanding must be a computed value** (`Total Claim − Verified Recoveries − Approved Adjustments`), never a field an employee types into directly.
5. Assignment: every case has a primary owner + optional supervisor + optional supporting employees. Every reassignment writes a row to `case_assignments` with assigned-by, assigned-to, date, reason — never just overwrite the owner field.
6. Build the Case detail page with tabs: Overview, Timeline, Financial (leave Activities/Tasks/Payments/Promises/Documents tabs as placeholders for now).
7. Quick actions on the case page: Add Note, Change Status, Escalate, Close Case (with reason). Closed cases become read-only for non-authorized roles; reopening requires a reason and writes an audit event.

**Before moving to Phase 4:** confirm you can create a case with a debtor, assign it to an employee, see the outstanding amount compute correctly (with 0 payments, outstanding = total claim), reassign it and see that logged, and close/reopen a case with the audit trail intact.

---

## PHASE 4 — Tasks, Activities, Calendar

**Goal:** everything an employee does becomes a trackable record, automatically — this is what later powers the Employee Activity Journal and KPIs.

1. Create tables: `tasks`, `activities` (calls, emails, meetings, notes, follow-ups — this generalizes the activity logging started in Phase 2 to also cover cases/debtors), `reminders`.
2. Task fields: title, description, related client/case/contact, assigned employee, created by, priority, status (To Do/In Progress/Waiting/Completed/Cancelled/Overdue — Overdue computed from due date, not manually set), start date, due date, completion date, result notes.
3. Every quick action on a case (Call Debtor, Add Note, etc.) must write an `activities` row automatically with employee, timestamp, related case, description, outcome. Do not require a separate manual "log this activity" step after the action — the action itself is the log entry.
4. Build task auto-creation rules: new case → review/contact-debtor/review-documents tasks; deadline approaching → escalation task. Keep this list short for v1; don't build a generic rules engine yet.
5. Build a Calendar view (day/week/month) showing tasks, follow-ups, and deadlines.
6. Build the **Employee Activity Journal**: a screen, filterable by employee and period (today/this week/this month/custom), that lists every activity + completed task that employee generated, purely as a query over existing data — no manual diary entry.

**Before moving to Phase 5:** log in as a Recovery Officer, do a handful of actions (create a task, complete it, log a call on a case), then check the Activity Journal shows exactly those actions with correct timestamps.

---

## PHASE 5 — Payments, Promises, Financial Integrity

**Goal:** money actually moving, tracked so it can never be silently altered.

1. Create tables: `payments`, `payment_verifications`, `promises_to_pay`, `settlements`.
2. Payment fields: case, debtor, amount, currency, date, method, reference, proof (document link), recorded by, verified by, status (Pending Verification/Verified/Rejected/Reversed). **Only a Verified payment affects the case's Outstanding calculation.** A reversal creates a new reversal transaction, never deletes the original.
3. Promise-to-pay fields: case, debtor, amount promised, promise date, expected payment date, status (Pending/Fulfilled/Partially Fulfilled/Broken/Cancelled), created by. Auto-flag a promise as overdue/broken once its expected date passes with no matching verified payment. Auto-create a follow-up task when a promise is created.
4. Recompute the case's Outstanding value live whenever a payment is verified.
5. Add Payments and Promises tabs to the Case detail page, with a Record Payment / Record Promise quick action.
6. Finance Officer role gets a "Pending Verification" queue to review and verify/reject submitted payments.

**Before moving to Phase 6:** record a payment, verify it, confirm the case's Outstanding drops correctly; create a promise, let its expected date pass, confirm it auto-flags as broken and shows in an alert somewhere.

---

## PHASE 6 — Documents, SLA, Aging

**Goal:** evidence attachment and time-based operational tracking.

1. Create `documents` table with categories (Contract, Invoice, Evidence, Correspondence, Payment Proof, Settlement, Legal, Other), attachable to clients, cases, and payments. Store files locally (Windows filesystem path referenced from the DB row) — not embedded as blobs unless you have a specific reason to.
2. Add configurable SLA rules (e.g. "new case first action within 24 hours", "high priority first contact within 4 hours") with start/end timestamps computed from actual case events, and a status of Within SLA / At Risk / Breached.
3. Compute case aging automatically: days since received, since last activity, since last debtor contact, since last payment. Bucket into 0–30 / 31–60 / 61–90 / 91–180 / 180+ for reporting.
4. Add Internal Note vs Client-Facing Note distinction — internal notes must never appear in any client-facing report generated later.

**Before moving to Phase 7:** upload a document to a case, confirm an SLA breach shows correctly on a case whose first-action deadline has passed, and confirm aging buckets look right on a couple of test cases with different `date_received` values.

---

## PHASE 7 — KPI Engine, Employee & Team Performance (the core of what you actually asked for)

**Goal:** the "will the boss easily see what Employee X did and whether this week's KPI is on point" requirement. This is the most important phase — take it slowly and verify every drill-down actually opens real records.

1. Create tables: `kpi_definitions`, `kpi_targets`, `kpi_results`, `employee_kpi_results`, `team_kpi_results`.
2. Build a small set of **predefined KPI calculation types** — do not build a generic custom-formula parser for v1, it's not worth the complexity yet:
   - `count` — e.g. tasks completed, calls made
   - `sum` — e.g. amount recovered
   - `ratio_percent` — e.g. (on-time follow-ups / required follow-ups) × 100
   - `average` — e.g. average case resolution time
   - `weighted_score` — combines several of the above with configured weights into one overall score
3. Each KPI definition has: name, category, calculation type, target, weight, period (weekly/monthly/etc.), applicable role. Seed these example KPIs for a Recovery Officer: Recovery amount (40% weight), Tasks completed (20%), Follow-up compliance (15%), SLA compliance (15% — wait, adjust weights to sum to 100 across whatever set you seed), Case closures (10%).
4. Build the KPI calculation job: run it over real rows (verified payments, completed tasks, logged calls, promise/payment matches, SLA timestamps) — never let a human type in a KPI number, per Phase 0 principle 1.
5. Build the **Employee 360° Performance page**: profile header, current work (assigned/active/overdue cases, tasks), activity counts (calls/meetings/follow-ups), financial performance (assigned claim value, recovered, outstanding, recovery rate), and a KPI table (Target | Actual | Achievement % | Status 🟢🟡🔴, using configurable thresholds, not hard-coded ones).
6. Make **every number on that page clickable**, opening the exact underlying records:
   - Click "Tasks: 35/40" → list of those 35 completed tasks, plus the 5 that are overdue/pending
   - Click "Recovery: RWF 12M" → list of cases/payments summing to that amount
   - Click "Follow-up: 64%" → list of the required follow-ups, marked on-time/late/missed
7. Build a "This Week / Last Week / This Month / Custom" period selector on the Employee 360° page that recalculates everything above for that window.
8. Build the Team Performance dashboard (aggregate of the employee view: team KPI average, top performers, employees below target, workload per employee).
9. Build KPI period closing: when a manager finalizes a week/month, snapshot the results so later data edits don't silently rewrite history — any post-finalization change gets logged as a recalculation event, not a silent overwrite.
10. Add a `difficulty` field to `cases` (Easy / Medium / Difficult / Very Difficult), settable manually by the case owner or supervisor for v1 — don't build an auto-scoring formula yet, that's a later refinement once you have real case data to calibrate against.
11. Add a workload panel next to the KPI table on the Employee 360° page: assigned case count, high-priority count, high-difficulty count, total assigned claim value, open tasks. This sits beside the KPI table, not blended into it — the manager should be able to see "this employee's KPI is 61%, and also has 41 cases including 15 difficult ones" as two separate, comparable facts, not a single adjusted score.
12. Add a KPI trend view on the Employee 360° page, reading from the finalized snapshots from step 9 (This Week / Last Week / This Month / Last Month / Quarter, as a simple table or line chart) — no new data model needed, this is a read over data you already snapshot.
13. Add a Team Performance ranking table (employee, KPI%, recovery%, tasks%, SLA%, workload) sortable by any column, visible only to Manager/Executive/Admin roles — do not expose this ranking to the Recovery Officer role itself unless a specific permission is granted.

**Before moving to Phase 8 — this is your acceptance test for the actual question you asked me:** log in as a Manager, open Employee Performance → pick a Recovery Officer → select "This Week" → confirm the KPI table shows real numbers, click into "Recovery" and "Tasks" and "Follow-up compliance" one at a time, and confirm each one opens the exact records behind it. If any of those clicks show a static number instead of a real list, that KPI is not built correctly yet — go back and fix it before continuing.

---

## PHASE 8 — Dashboards, Reports, Alerts

**Goal:** the different logins each land on the view relevant to them.

1. Build role-specific dashboards on login:
   - Recovery Officer: my tasks today, my cases, my KPI progress, alerts (overdue work, broken promises)
   - Manager: team KPI, workload by employee, cases needing intervention
   - Executive/Director: business overview (recovery, outstanding, cases, clients), operations (overdue, SLA breaches), people (team KPI, top/bottom performers), financial (recovery by period/client/employee)
2. Add visual charts to the Manager and Executive dashboards, not just numbers/tables — this is a real gap to close, not optional polish: a bar chart of cases by status, a bar chart of recovery amount by employee, and a line chart of KPI trend over recent periods (reading from the Phase 7 finalized snapshots). Use the `fl_chart` package or equivalent. Keep the Recovery Officer's own dashboard to numbers/lists — charts matter most where someone is comparing across cases or people, not looking at their own single set of tasks.
3. Build performance alerts: notify a manager when an employee's KPI drops below threshold, has excessive overdue tasks, or has broken promises needing action. Keep the rule set small and configurable rather than hard-coding every possible alert.
4. Build report generation (PDF/CSV export) for: Recovery Report, Employee Performance Report, Client Monthly Report (exclude internal notes per Phase 6), Aging Report.
5. Build the Windows toast notifications (local_notifier) for new assignments, overdue tasks, and SLA risk.

**Before moving to Phase 9:** log in as each role and confirm the dashboard shown is actually relevant to that role, not a generic screen with visibility toggled.

---

## PHASE 9 — Hardening, Bulk Import, Final Test

**Goal:** production-readiness.

1. Add CSV/Excel bulk case import (upload → map columns → validate → preview → confirm → import report), with duplicate detection.
2. Integrate the Elvium HMAC-SHA256/RSA licensing system (Master activation, Worker LAN token, offline grace period) — reuse the existing module, don't rebuild.
3. Security pass: confirm every permission is enforced in the data-access layer (not just UI), input validation on all forms, no sensitive data in logs, rate limiting on login attempts.
4. Performance pass: pagination and indexes for a workload of ~100+ employees, thousands of cases, and a growing activities table — don't load large lists into memory unfiltered.
5. Run the full final acceptance test below.

### Final acceptance test (run this yourself before calling the app done)

A Manager logs in → Performance → Employee Performance → selects an employee → selects "This Week." The KPI table, targets, actuals, and weighted score appear. Manager clicks Recovery and sees the exact cases/payments behind the number. Clicks Tasks and sees exactly which are completed/pending/overdue. Clicks Follow-up Compliance and sees the exact follow-ups counted. Clicks the Activity Journal and sees a real timeline of what that employee did this week. Clicks into a case from that list and sees its full history. Clicks Audit Log and sees who changed what, when.

If every one of those clicks resolves to real data with no placeholders, the app matches what you asked for.

---

---

## PHASE 10 (FUTURE — do not build yet) — Supabase Cloud Backend

Only start this once Phases 1–9 are stable and the company has decided it's ready to pay for hosting.

**Goal:** replace `LanSyncAdapter` with `SupabaseSyncAdapter` so any PC, anywhere, on any internet connection, syncs to one shared cloud database — without touching the Repository layer, UI, KPI engine, or business logic built in Phases 1–9.

Rough scope when this phase is started: Supabase Postgres schema mirroring the local SQLite schema, Row Level Security policies matching the existing RBAC roles, Supabase Auth wired in behind the existing `AuthRepository` (not replacing it), a `SupabaseSyncAdapter` implementing the same interface as `LanSyncAdapter`, and remote file storage for documents. The Master/Worker LAN concept goes away at this point — every PC becomes a thin client syncing directly to Supabase.

## PHASE 11 (FUTURE — only if truly needed) — Offline-Resilient Cloud Sync

Only relevant if, after moving to Supabase, field officers regularly work with no internet for extended periods and need full offline capability against the cloud backend (not just LAN). This adds real conflict-resolution complexity (two people editing the same case while both offline) and should not be attempted until there's a concrete, observed need for it — don't build this speculatively.

---

## Notes for you (not part of the Antigravity prompt)

- **Current limitation, be aware of it going in:** this LAN-only design means employees only see each other's data while their PC is on the same office WiFi as the Master PC. A field officer working from mobile data will not sync in real time — their changes queue locally and sync once they reconnect to the office network. This is expected and fine for a first version, but it's not the "boss sees everything live from anywhere" outcome — that only fully arrives once you migrate to Supabase. Make sure whoever signs off on v1 understands this trade-off up front, so it isn't a surprise later.
- Demo data: use fictional client names ("Telco One Rwanda", "Metro Insurance Ltd") rather than the real MTN/Airtel — safer if this ever leaves your internal testing environment.
- Debtor personal data (phone, address, employer) is personal data under Rwanda's data protection law — the permission-gating in Phase 3 step 3 is there for that reason, don't skip it even for internal MVP use.
- If Antigravity produces something inconsistent with the Master/Worker LAN pattern (e.g. tries to build a cloud backend instead), stop and correct it before continuing — that architectural choice needs to hold across every later phase, the same way it does in HarvestSync.
