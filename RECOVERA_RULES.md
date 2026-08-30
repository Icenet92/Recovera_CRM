# RECOVERA — STANDING RULES (read this first, every session, regardless of which tool you are)

This file is universal — it applies whether you are Google Antigravity, OpenCode, Claude, or any other AI coding tool working on this project. It does not belong to one tool. Read it in full before touching any code, and hold yourself to it for the entire duration of your work on this project, not just your first response.

Recovera is a Client, Case & Recovery Management Platform for a company that recovers unpaid money on behalf of corporate clients (example: a telecom client paid an agent/vendor who then failed to deliver, and Recovera's company is hired to recover the money from that debtor).

This file does not describe what to build feature-by-feature — that's in the separate phased build plan document. This file describes HOW to build it, and the rules here override convenience or shortcuts every time, in every phase.

---

## FIXED TECH STACK (do not substitute, do not "improve" unasked)

- Flutter, targeting Windows desktop
- State management: Provider
- Local database: sqflite_common_ffi (SQLite)
- LAN networking: shelf + shelf_router (HTTP server), bonsoir (mDNS discovery), http (client)
- Fonts: Google Fonts Inter. Custom title bar via bitsdojo_window — scaffold once, do not touch window-chrome code afterward.
- Windows toast notifications via local_notifier
- Licensing (from Phase 9 onward): the existing Elvium HMAC-SHA256 + RSA licensing system — ask for the existing module, do not invent a new licensing scheme

## DATA ACCESS RULE

- Every screen, Provider, and business-logic module (KPI engine, reports, etc.) talks ONLY to a Repository layer (e.g. `CaseRepository`, `UserRepository`) — never to SQLite queries directly. The Repository is the only thing that knows how a record is actually stored and fetched.
- The app always reads and writes its own LOCAL SQLite database, full stop — this never changes, including if a cloud backend is added later. What changes over time is only how that local data gets replicated elsewhere.
- Every table has UUID primary keys (not auto-increment integers) and four sync columns from day one: SyncCreatedAt, SyncUpdatedAt, IsDeleted, DeletedAt — unless it is explicitly, deliberately local-only (see sync rule below).

## LAN SYNC ARCHITECTURE (V1)

- One PC acts as MASTER (authoritative database + a `shelf`/`shelf_router` HTTP server), other PCs act as WORKERS that discover it via mDNS (bonsoir) and sync over HTTP.
- Every request authenticated via a shared secret header (`X-Office-Key`). Rotating this key immediately disconnects every other device until they re-enter it.
- Sync progress is tracked PER TABLE (a `sync_state` table: TableName, LastSyncedUpdatedAt), not one global timestamp.
- Conflict handling is TWO separate mechanisms, never collapsed into one:
  1. Live edit locking — a device must acquire a row-level lock before editing a record. Include role-based priority for disputes and an admin "force-clear all locks" action.
  2. Replication-time conflict resolution — incoming records during sync are merged through a dedicated resolver (newer `SyncUpdatedAt` wins; malformed timestamps fail open and accept incoming; exact ties do nothing), never a blind overwrite.
- On Master startup (Windows only), auto-add a Windows Firewall rule for the sync port via `netsh advfirewall`. This step must be skipped gracefully (not crash) on any non-Windows target.
- A delta-pull request for a table missing its sync column should return an empty result, not a server error.
- The Master's database is the authoritative replica for LAN sync in V1 ONLY — not a permanent architectural fact. A later cloud backend (Supabase) will replace this pattern entirely via a swapped `SyncAdapter` implementation, not run alongside it. Never design anything as if "the Master PC" is permanent.
- Workers must reach all business data ONLY through `Repository → local SQLite → SyncAdapter → Master`. Never an ad hoc call directly into the Master's database outside that path.

## FUTURE-BACKEND ABSTRACTION

- Replication is handled by a single `SyncAdapter` interface (`pushChanges()`, `pullChanges(since)`, `getConnectionStatus()`), kept completely separate from the Repository layer.
- Only ONE SyncAdapter implementation is ever active at a time. A future cloud implementation REPLACES the LAN one — they never run simultaneously and never sync to each other.

## NON-NEGOTIABLE PRINCIPLES (apply to every phase, every tool, no exceptions)

1. **Every KPI number must be calculated from real database rows** (COUNT, SUM, ratio queries) — never manually typed or hard-coded, except clearly-labeled demo seed data.
2. **Every KPI number must be clickable and open the exact underlying records** that produced it. Summary → Detail → Evidence, everywhere, no exceptions.
3. **Every button must actually work.** No placeholder charts, fake search, fake notifications, or dead-end forms.
4. **Financial records are never hard-deleted.** A wrong payment gets a reversal transaction, not a delete. A closed case is locked until reopened with a logged reason.
5. **Do not build ahead of the current phase.** Wait for the next phase's instructions before adding features from later phases, even if they seem related.
6. **Permission seeding is required in EVERY phase that adds a permission.** Whenever a new permission code is introduced, immediately add `role_permissions` rows for every role that should reasonably have it — not just the one role the feature was built for. Super Administrator must bypass permission checks entirely (never depend on seeded rows) so this bug class cannot recur for that role. Every other role's permission coverage must be shown as a matrix as part of that phase's verification — a runtime "lacks permission" error on an existing role is a bug, not an edge case to shrug off. If a Roles management screen exists, it must read the permissions table dynamically, never from a hardcoded list.
7. **Sync-table registration is required in EVERY phase that adds a table meant to replicate.** New tables must be added to the sync-eligible list (e.g. `kSyncedTables`) in the same phase they're created — this has already been missed once (Phase 2/3 tables were left out) and must not happen again. If a table is intentionally local-only, document why next to the exclusion. Every phase's verification must include an actual two-machine sync test of any new table, not just confirming the schema exists.
8. **After any structural change (new table, new permission, new sync-eligible entity), do a self-audit for other registries that might also need updating** — a per-table registry problem (rule 7) and a per-role permission problem (rule 6) are the same failure pattern; assume there may be others (export mappings, bulk-import column mappings, report definitions) and check before declaring a phase complete.

## WHEN REPORTING WORK AS DONE

- Do not report a feature as complete based on the plan description alone — state specifically what was tested and how (e.g. "created a case, closed it with an empty reason, confirmed rejection; reopened it, confirmed audit log entry").
- If something was intentionally deferred, partial, or built as a placeholder, say so explicitly and name which future phase it belongs to — do not let a partial implementation read as "done."
- If a fix changes behavior for one role/table/case, check whether the same fix is needed elsewhere before calling it finished (see rule 8).
