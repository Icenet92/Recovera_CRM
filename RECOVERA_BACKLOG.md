# RECOVERA — Outstanding Fixes Backlog

## How to use this file

Work through the items below **in order, one at a time.** Do not start the next item until the previous one is actually verified working (not just implemented) — check it off with a one-line note on how it was verified. If an item is blocked or partially done, say so explicitly next to it rather than marking it done.

When a new issue is found later, it gets added to the bottom of this list — this file is the single source of truth for "what's still open," not a chat message.

---

- [x] **1. Confirm GitHub push status.** DONE — renamed local branch `master` → `main`; `git remote add origin https://github.com/Icenet92/Recovera_CRM.git`; `GIT_TERMINAL_PROMPT=0 git push -u origin main --force` → `branch 'main' set up to track 'origin/main'` and `+ 5ee890e...2bbbc0d main -> main (forced update)` (replaced GitHub's throwaway `5ee890e` initial commit with the real project history ending at `2bbbc0d`), EXITCODE=0. Authenticated automatically via the cached Git Credential Manager entry for `github.com` (no 401). Verified by push output + `git remote -v` showing `origin` and `git branch` showing `main` tracking `origin/main`.

- [ ] **2. Add a "Batches" list screen** (sidebar route) showing all Recovery Assignments — filterable by status (Active/Completed/Cancelled), each row clicking through to the existing batch detail screen. Right now a batch is only reachable via a pooled case.

- [ ] **3. Case Reassign dialog + Add Supporting Officer dialog** currently show raw "Employee ID" text fields with placeholder "Enter employee ID" — no names, no dropdown. Replace both with a searchable dropdown showing "Full Name — Job Title," backed by the ID underneath, sourced the same way as the batch form's officer picker (which already works correctly — use that as the reference implementation, don't rebuild from scratch).

- [ ] **4. Case Detail screen: "Debtor: Loading..." never resolves.** It's stuck permanently, not just slow. Find why the debtor name lookup for a case isn't completing and fix it.

- [ ] **5. Batch form case picker scaling.** Currently shows every case in the company as one flat list (case number + title only). Add a Client filter/selector above the list to narrow it down, and show each case's debtor name on its row. Cases from more than one client must remain selectable together in one batch if the manager wants that — this is a filter for convenience, not a restriction to one client per batch.

- [ ] **6. Batch form Target Amount clarity + verify override works.** Add a hint label under the field: "Auto-suggested from total outstanding — adjust as needed." Separately confirm: does manually editing this value and saving actually persist the edited number, or does it silently revert to the auto-summed total? If it reverts, that's a bug — fix it so a manager can set any target they choose, independent of the sum of pooled cases' outstanding amounts.
