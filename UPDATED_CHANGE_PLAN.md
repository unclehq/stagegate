# Updated Change Plan

Omitted sections: none.

## Disposition table

| Finding | Disposition | Reason | Exact plan change |
|---|---|---|---|
| AR-001 (Critical — stale state closes wrong issue) | Accepted | The reviewer is correct: run-id alone identifies the *invocation*, not the *subject*. Nothing previously bound `.workflow/state` to a repo+issue identity, so a resumed run for issue A can close issue B. | New `.workflow/origin` file (repo, issue) written before the driver is first invoked; `change-workflow.sh` refuses to proceed — no state mutation, no `FINAL_AUDIT`, no close — on any origin mismatch or on unresolvable foreign state. `from-issue.sh` refuses to overwrite `CHANGE_REQUEST.md` under the same condition. See §1.1, §7, §12. |
| AR-002 (Critical — stale audit relabeled current) | Accepted | Confirmed: nothing removed or freshness-checked `FINAL_AUDIT.md` before `run_codex`; `require_file` only checks non-emptiness. A reviewer invocation that no-ops leaves the prior verdict readable as if fresh. | `rm -f FINAL_AUDIT.md` immediately before `run_codex` in `FINAL_AUDIT` (mirrors the background path's existing pattern); `require_file` now fails on absence, not just emptiness, so a no-op reviewer is a hard error. Verdict file gains a third field: sha256 of the exact `FINAL_AUDIT.md` bytes classified. See §1.2, §9, §12. |
| AR-003 (Critical — concurrent runs cross-contaminate) | Accepted | Confirmed: `.workflow/` was assumed single-writer but nothing enforced it; two confirmed invocations can interleave around the same shared paths. | New exclusive lock (`.workflow/lock`, PID-stamped, `mkdir`-atomic) acquired at the start of `change-workflow.sh main`, held for the whole run, released via `trap ... EXIT`. A second invocation refuses to start while a live PID holds it. See §1.3, §11, §12. |
| AR-004 (High — pause/resume loses provenance) | Accepted | Confirmed: resuming via either script had no durable link back to the originating issue, and `from-issue.sh` unconditionally overwrote `CHANGE_REQUEST.md` on any rerun. | `.workflow/origin` (AR-001's mechanism) is the durable link, written once before the first driver invocation and read on every resume attempt. `from-issue.sh` skips rewriting `CHANGE_REQUEST.md` when `.workflow/origin` already names the same (repo, issue) and state is non-empty and non-`COMPLETE` — it re-enters the confirmation/run flow against the existing seed instead. See §1.1, §6, §12. |
| AR-005 (High — verdict parsing brittleness) | Accepted | Confirmed: "last line containing a phrase anywhere" accepts trailing prose, headings, or a `NOT READY` finding followed by unrelated boilerplate ending in `READY`. | Classifier now reads only the last non-blank line, strips markdown emphasis/heading markers and surrounding whitespace, and requires an exact match to one of the three phrases. Any other content on that line, or multiple lines with a bare `READY`-like fragment, classifies `UNKNOWN`. See §1.4, §16. |
| AR-006 (High — non-TTY path contradicts spec) | Accepted | CHANGE_SPEC §8 explicitly and knowingly breaks compatibility for non-interactive callers; CHANGE_PLAN's no-TTY softening silently reinterpreted an already-approved acceptance criterion instead of asking for re-approval. Per core rule 6 and the reviewer's finding, the plan must match the approved spec, not quietly diverge from it. | Drop the `[ -t 0 ]` check entirely. Non-interactive callers hit the same `read`-based exact-word prompt as an interactive terminal and block on it, exactly as CHANGE_SPEC §8 and §9 require. See §1.5, §8, §10. |
| AR-007 (High — no end-to-end close test) | Accepted | Confirmed: the only automated coverage was the pure classifier; the irreversible `gh issue close` call itself was reachable only through manual checks. | New `scripts/tests/close-flow-test.sh`: hermetic, stubs `gh` and the reviewer command, drives `confirm_and_run_workflow` + `close_issue_if_ready` through every branch in the error table (§12) and asserts exact stdout markers and exit codes. See §1.6, §16. |
| AR-008 (Medium — `if !` erases driver status) | Accepted | Confirmed: `if ! change-workflow.sh; then` under `set -e` discards the real exit code where the branch needs it; the reviewer's fix is strictly correct and free. | Explicit status capture: `status=0; "$ROOT/scripts/change-workflow.sh" ...arguments... || status=$?`, branch and propagate on the stored variable, never on `!`'s truth value. See §1.7, §12. |

No finding is rejected, partially accepted, or deferred. All eight are adopted as written; §22 below records the residual risk each one does *not* fully close.

## 1. Selected technical approach

Retains CHANGE_PLAN §1's three-edit shape (classifier lib, driver, seeder) but adds four new mechanisms the review showed were missing, and reverses one deviation from the approved spec. Numbered to match the disposition table above.

### 1.1 Origin binding (AR-001, AR-004)

New file `.workflow/origin` (gitignored, alongside `state`, `cost.tsv`, `audit-verdict`): one line, `<repo>\t<issue-number>`. Written by `from-issue.sh` inside `confirm_and_run_workflow()`, after the user confirms and immediately before the first invocation of `change-workflow.sh` — never before confirmation, so a decline leaves no origin claim behind.

`change-workflow.sh` gains a preflight check in `main`, run once, before any state dispatch and immediately after the lock (§1.3) is acquired:

- If invoked with `STAGEGATE_ORIGIN_REPO`/`STAGEGATE_ORIGIN_ISSUE` set (i.e., launched by `from-issue.sh`) **and** `.workflow/state` is non-empty and not `COMPLETE`:
  - If `.workflow/origin` is absent → refuse. Foreign or pre-existing state cannot be proven to belong to this issue.
  - If `.workflow/origin` is present but its (repo, issue) does not match the env vars → refuse.
  - Refusal prints both identities, exits non-zero, and touches nothing else — no state write, no `FINAL_AUDIT`, no lock is left held (released by the `EXIT` trap).
- If `.workflow/state` is empty/absent, or is `COMPLETE`, the check passes trivially and `.workflow/origin` is (re)written to the current invocation's identity as part of `ANALYZE` startup, since a fresh or completed-and-restarted run legitimately claims the checkout anew.
- Invoked standalone (no `STAGEGATE_ORIGIN_*`) the check is skipped entirely — a human running `change-workflow.sh` by hand is unaffected, preserving B-10 compat.

`from-issue.sh` performs the mirror-image check *before* calling `write_change_request`: if `.workflow/origin` names a different (repo, issue) and `.workflow/state` is non-empty and non-`COMPLETE`, it refuses to overwrite `CHANGE_REQUEST.md` and tells the user which issue currently owns the checkout — this closes the "unconditionally overwrites" half of AR-001 that the driver-side check alone cannot reach. If `.workflow/origin` names the *same* (repo, issue), `from-issue.sh` skips `write_change_request` (the seed already reflects this issue, possibly hand-edited per I-07) and goes straight to the confirmation prompt, addressing AR-004's "resume path that neither refetches nor rewrites the request."

`close_issue_if_ready()` re-reads `.workflow/origin` at close time and requires it to still name the issue currently being processed, as a check independent of the run-id match already planned — two independent identity checks must agree before any `gh issue close`.

### 1.2 Fresh-audit binding (AR-002)

In `FINAL_AUDIT`, immediately before invoking `run_codex`: `rm -f FINAL_AUDIT.md`. This mirrors the background-audit path's existing removal at line 443 (evidence cited by the reviewer), so a reviewer invocation that exits 0 without writing output leaves `require_file` nothing to accept — `require_file` already treats absence as failure; only non-emptiness was previously the sole check *given* the file existed, and removal beforehand makes existence itself the freshness proof.

The verdict file `.workflow/audit-verdict` gains a third tab-separated field: `sha256sum FINAL_AUDIT.md` computed at the moment of classification. Format becomes `<run-id>\t<verdict-class>\t<sha256>`. `close_issue_if_ready()` recomputes the hash of the on-disk `FINAL_AUDIT.md` immediately before closing and refuses (prints why, no close) if it no longer matches — this is the belt to the lock's suspenders (§1.3): even if a lock-bypassing process or a hand-edit replaced the file between classification and close, the stale-content case is still caught.

### 1.3 Single-writer lock (AR-003)

`change-workflow.sh main` acquires an exclusive lock before touching `.workflow/state` or any other shared path: `mkdir "$ROOT/.workflow/lock"` (atomic — `mkdir` on an existing directory fails). On success, write `$$` into `.workflow/lock/pid` and register `trap 'rm -rf "$ROOT/.workflow/lock"' EXIT` so the lock releases on every exit path, success or failure.

On `mkdir` failure: read `.workflow/lock/pid`; if that PID is alive (`kill -0`), refuse to start — print "another change-workflow.sh run (pid N) holds this checkout" and exit non-zero, no state touched. If the PID is dead (a prior run was killed without cleanup), remove the stale lock directory and retry once.

This makes AR-003's interleaving scenario structurally impossible: the second invocation blocks at the lock before it can touch `FINAL_AUDIT.md`, `.workflow/state`, or the verdict file, rather than racing mid-`FINAL_AUDIT`.

### 1.4 Exact verdict-line matching (AR-005)

`classify_audit_verdict()` no longer scans for the last line *containing* a phrase anywhere in the file. It now: takes the last non-blank line of `FINAL_AUDIT.md`; strips leading/trailing whitespace and markdown emphasis/heading markers (`*`, `_`, `#`); requires the remainder to be an *exact* match (case-sensitive, per `prompts/change/final-audit.md:54-58`'s own casing) to one of `READY`, `READY WITH NON-BLOCKING ISSUES`, `NOT READY`. Any other content on that final line — trailing prose, a heading, two phrases concatenated, text following `NOT READY` — classifies `UNKNOWN`. Multi-line conclusions (a phrase alone on a line, followed by a blank line, followed by trailing footer prose) are handled by "last *non-blank* line," which will land on the footer and correctly return `UNKNOWN` rather than the phrase two lines up — fail-closed, matching I-08's intent.

### 1.5 Non-TTY reversal (AR-006)

CHANGE_PLAN §10's `[ -t 0 ]` early-decline is removed outright. `confirm_and_run_workflow()`'s prompt is a plain `read` with no TTY precondition: a non-interactive caller (piped stdin, cron, CI) blocks on it exactly as CHANGE_SPEC §8 states, and as `human_gate()` already does elsewhere in the driver (I-01 precedent). This is the approved compatibility break, not a plan-level softening of it.

### 1.6 Hermetic close-flow test (AR-007)

New `scripts/tests/close-flow-test.sh`: no network, no real `gh`. A fake `gh` executable and a fake reviewer command are placed earlier on `PATH` inside a scratch copy of the repo; the fakes are table-driven (read an expected-call log, echo canned output, exit with a scripted code). The test drives `from-issue.sh`'s `confirm_and_run_workflow` + `close_issue_if_ready` (sourced, not the full CLI, to keep it hermetic) through every row of the error table in §12 and asserts the exact stdout marker and exit code for each, not merely "did not crash."

### 1.7 Explicit status capture (AR-008)

CHANGE_PLAN §20's prescribed `if ! "$ROOT/scripts/change-workflow.sh" ...; then` is replaced by:

```
status=0
"$ROOT/scripts/change-workflow.sh" "$@" || status=$?
if [ "$status" -ne 0 ]; then
  ...no close, propagate $status...
fi
```

`set -euo pipefail` remains in force; the `|| status=$?` form is the standard safe pattern for capturing a failing command's code under `set -e` without triggering it, per the reviewer's recommendation.

## 2. Alternative approaches considered

Unchanged from CHANGE_PLAN.md § 2.

## 3. Why the selected approach is preferred

Unchanged from CHANGE_PLAN.md § 3. The additions in §1.1–§1.7 above extend rather than replace that reasoning: they confine every new safety mechanism (origin file, lock, hash binding) to the same two call sites (`FINAL_AUDIT` in the driver, the two new functions in the seeder) that §3 already scoped the I-05 relaxation to.

## 4. Exact components to modify

| Component | Anchor | Edit |
|---|---|---|
| `scripts/lib/audit-verdict.sh` | new | `classify_audit_verdict()` — exact-last-line matching (§1.4) |
| `scripts/tests/audit-verdict-test.sh` | new | fixture assertions for the classifier, extended with AR-005 malformed-input fixtures |
| `scripts/tests/close-flow-test.sh` | new | hermetic end-to-end close-decision coverage (§1.6) |
| `scripts/change-workflow.sh` | after `hash_file`, ~line 114 | source the lib (self-relative, I-04) |
| `scripts/change-workflow.sh` | start of `main`, before state dispatch | acquire/release lock (§1.3); origin preflight check (§1.1) |
| `scripts/change-workflow.sh` | `FINAL_AUDIT`, 663-670 | `rm -f FINAL_AUDIT.md` before `run_codex`; write `.workflow/audit-verdict` with the third hash field; echo the class |
| `scripts/change-workflow.sh` | `ANALYZE` startup | (re)write `.workflow/origin` when state was empty/`COMPLETE` |
| `scripts/from-issue.sh` | `write_change_request`, 206-208 | drop the trailing `Run:` hint; gate the call on the origin check (§1.1) |
| `scripts/from-issue.sh` | fetch block, 94-100 | set `USED_GH=1` only when `fetch_with_gh` produced the JSON |
| `scripts/from-issue.sh` | new fns before dispatch | `confirm_and_run_workflow()` (no TTY precondition, §1.5; explicit status capture, §1.7; writes `.workflow/origin`), `close_issue_if_ready()` (origin match + run-id match + hash match, §1.1/§1.2) |
| `scripts/from-issue.sh` | dispatch, 300-303 | `change)` branch calls the two new functions |
| `README.md` | 114-133 | document the confirmation + auto-run + auto-close flow, including the blocking non-interactive prompt and the origin/lock refusal messages |
| `scripts/README.md` | 63-82 | same, plus the `gh`-required-for-close note and the lock/origin contract |

## 5. Components explicitly not to modify

Unchanged from CHANGE_PLAN.md § 5.

## 6. Data-flow changes

```
from-issue.sh: generate RUN_ID ──export STAGEGATE_RUN_ID──────────────┐
from-issue.sh: confirm ────────write .workflow/origin──────────────────┼──> change-workflow.sh
                                export STAGEGATE_ORIGIN_REPO/ISSUE ────┘
change-workflow.sh main: acquire .workflow/lock (exclusive, whole run)
change-workflow.sh ANALYZE: (state empty/COMPLETE) ──rewrite──> .workflow/origin
change-workflow.sh *: origin preflight ──refuse on mismatch/foreign state──> exit, no writes
change-workflow.sh FINAL_AUDIT: rm -f FINAL_AUDIT.md ──run_codex──> FINAL_AUDIT.md
                                  ──classify + sha256──> .workflow/audit-verdict
                                                          ("<RUN_ID>\t<CLASS>\t<SHA256>")
from-issue.sh (after driver returns) ──read+match RUN_ID + origin + sha256──> gh issue close
```

`USED_GH` (set at fetch, read at close) is unchanged from CHANGE_PLAN.md §6. Nothing else changes: `CHANGE_REQUEST.md` content (when actually (re)written), `.workflow/state`, approvals, logs, and the cost ledger are byte-identical in shape to CHANGE_PLAN.md's baseline.

## 7. State-transition changes

None to the state machine's node set. `ANALYZE → … → FINAL_AUDIT → COMPLETE` is unchanged; no state is added, removed, or reordered. Two new *cross-cutting* steps wrap the whole machine rather than living inside a single state: the lock is acquired/released around the entire `main` run (§1.3), and the origin preflight check runs once before dispatch and can now terminate the process before `ANALYZE` is ever entered (§1.1) — this is new: CHANGE_PLAN's version had no path that stopped the driver before its first state. `FINAL_AUDIT` itself still gains exactly one side effect (write the verdict file) after `run_codex` and before `set_state COMPLETE`, now preceded by the `rm -f` (§1.2).

`from-issue.sh` gains a linear post-write sequence: `origin check → (foreign, non-empty, non-COMPLETE state: refuse, exit) | (same origin or fresh: seed/skip-seed → confirm (blocks, no TTY bypass) → (decline: print hint, exit 0) | (accept: write origin → run driver → verdict+origin+hash check → close | skip))`.

## 8. Interface and API changes

| Surface | Change |
|---|---|
| `from-issue.sh` CLI flags | none — no new flags (B-09, §8) |
| `from-issue.sh --change` stdout | `Run:` hint moves from the success path to the decline path; adds the seeded-file echo (or "resuming existing seed for this issue" when skipping the rewrite), pre-flight warnings, prompt, driver output, close/skip/refuse message |
| `from-issue.sh --new` | none (B-08) |
| `from-issue.sh` exit codes | 0 on decline and on completed-run-with-close-skipped; non-zero if the driver fails, `gh issue close` fails, or the origin/lock preflight refuses |
| `change-workflow.sh` CLI | none (`-h`, `--version`, unknown-arg, no positionals all unchanged) |
| `change-workflow.sh` env | reads new optional `STAGEGATE_RUN_ID` (unchanged from CHANGE_PLAN) and new optional `STAGEGATE_ORIGIN_REPO`/`STAGEGATE_ORIGIN_ISSUE`; absent → origin preflight and rewrite are skipped entirely, verdict file still writes `-` for run-id |
| `change-workflow.sh` non-interactive behavior | none removed — no prior blocking behavior existed to preserve; this is the driver, not the seeder |
| `from-issue.sh` non-interactive behavior | now blocks on `read` with no TTY precondition (§1.5) — the approved compatibility break, reversing CHANGE_PLAN §10's softening |
| GitHub | new write: `gh issue close --comment` (I-05 RELAXED), now gated on three independent matches (run-id, origin, audit hash) instead of one |

## 9. Schema or persistence changes

Two new files plus one widened file, all gitignored alongside `state` and `cost.tsv`:

- `.workflow/origin` — one line, `<repo>TAB<issue>`. Written before the first driver invocation for a confirmed run and rewritten only when starting fresh or restarting after `COMPLETE`. Absent file combined with empty/`COMPLETE` state is always valid (fresh run); absent file combined with non-empty, non-`COMPLETE` state blocks auto-invocation (§1.1).
- `.workflow/lock/` — a directory (not a file, so `mkdir` provides atomicity) containing `pid`. Exists only for the duration of one `change-workflow.sh` run; removed by an `EXIT` trap. No reader other than the next `change-workflow.sh` invocation's own startup check.
- `.workflow/audit-verdict` — CHANGE_PLAN's one-line TSV widens from two fields to three: `<run-id>TAB<class>TAB<sha256>`, overwritten each time `FINAL_AUDIT` runs. No reader other than `from-issue.sh`; absent file is always valid and means "no verdict from this run." No existing file format (`state`, `cost.tsv`, `CHANGE_REQUEST.md`) changes.

## 10. Compatibility strategy

- `--new` path untouched (B-08); verified by diffing its output against the current script's.
- `change-workflow.sh` standalone: unchanged CLI, unchanged `COMPLETE` output apart from one added verdict line, unchanged `exit 0` (B-10). Running it by hand never sets `STAGEGATE_ORIGIN_*`, so the origin preflight check is skipped entirely — standalone use is affected only by the new lock (harmless for the single-run case the current docs already assume; a second concurrent standalone invocation now gets an explicit refusal instead of silent corruption, which is a strict improvement, not a break). The verdict file still records `-` for run-id when `STAGEGATE_RUN_ID` is absent, so it can never satisfy a later close check.
- **Non-interactive callers.** CHANGE_PLAN §10's `[ -t 0 ]` early-decline is withdrawn (AR-006, accepted). A scripted caller of `from-issue.sh --change` now hits the same blocking prompt a TTY would, per CHANGE_SPEC §8's explicitly approved compatibility break. This is no longer flagged as a deviation — it is the approved behavior, restored.

## 11. Concurrency implications

CHANGE_PLAN §11 assumed `.workflow/` was single-writer without enforcing it; the reviewer showed that assumption false under two confirmed invocations. The lock in §1.3 makes it true: `change-workflow.sh` now holds an exclusive `mkdir`-based lock for its entire run, so a second invocation against the same checkout refuses to start rather than racing on `FINAL_AUDIT.md`, `.workflow/state`, or the verdict file. Stale locks from a killed process are detected via a liveness check on the recorded PID and cleared automatically (this is not core-rule-13 state deletion — the lock is not workflow state, it is a run-scoped mutex with no meaning once its owning process is dead). The audit-hash field in `.workflow/audit-verdict` (§1.2) is a second, independent guard against the same class of interleaving, in case a future caller invokes the driver with the lock bypassed (e.g. a manual `rm -rf .workflow/lock`) — belt-and-suspenders, not a substitute for the lock.

## 12. Error and recovery behavior

| Condition | Behavior | Spec ref |
|---|---|---|
| No TTY on stdin | prompt anyway; blocks on `read` like any other invocation (§1.5) | §8, B-01/B-02 |
| Prompt gets EOF or non-exact input | decline: hint, exit 0, no driver, no close | §9, B-03 |
| Driver exits non-zero | report the failure plainly (status captured explicitly, §1.7), no close, propagate non-zero | §9, B-06 |
| Driver exits 0 via a **declined internal gate** (`change-workflow.sh:226`) | no verdict file for this run id → no close | B-06 |
| Driver exits 0 from a stale `COMPLETE` state | `FINAL_AUDIT` never ran this invocation → no matching verdict → no close | B-06 |
| `.workflow/audit-verdict` missing, malformed, run-id mismatched, origin mismatched, or sha256 mismatched | no close; print why (each check is independent and any one failing blocks close) | I-08 |
| `.workflow/origin` names a different (repo, issue) and state is non-empty, non-`COMPLETE` | `from-issue.sh` refuses to seed or invoke; driver, if invoked directly with mismatched `STAGEGATE_ORIGIN_*`, refuses at preflight; no writes, no close | AR-001, AR-004 |
| `.workflow/state` non-empty, non-`COMPLETE`, `.workflow/origin` absent, `STAGEGATE_ORIGIN_*` set | refuse — foreign/legacy state with no provable owner | AR-001 |
| `.workflow/lock` held by a live PID | driver refuses to start; no state touched | AR-003 |
| `.workflow/lock` held by a dead PID | stale lock cleared, driver proceeds | AR-003 |
| `FINAL_AUDIT.md` not recreated after `run_codex` exits 0 | `require_file` fails hard (the `rm -f` beforehand removed any stale copy) | AR-002 |
| Class is `NOT_READY` or `UNKNOWN` | issue left open; print the verdict and why | B-05, I-08 |
| Fetch used the `curl` fallback (`USED_GH=0`) | skip close, explicit message, exit reflects the successful run | B-07, I-09 |
| `gh` missing or unauthenticated at close time | same as above — skip + message, not a hard failure | §9, I-09 |
| `gh issue close` itself fails | print the error, exit non-zero, and state explicitly that the workflow completed and only the close failed | §9 |

Implementation traps to respect (both are `set -euo pipefail` scripts): `read` returns non-zero on EOF and must be wrapped in `if !`/`|| true`; `gh auth status` returns non-zero when logged out and must be wrapped the same way; the driver invocation itself must **not** use bare `if !`, per AR-008 — use the explicit `status=0; cmd || status=$?` form (§1.7) since its exit code is needed later, not just its truth value.

## 13. Migration plan

Omitted (unchanged from CHANGE_PLAN.md — no persisted schema/data format migrates; `.workflow/origin` and `.workflow/lock` are new state, created fresh and treated as absent-if-missing, same as `.workflow/audit-verdict` already was).

## 14. Rollback plan

1. `git revert` the change's commits (or `git checkout <prev> -- scripts/ README.md scripts/README.md`). `from-issue.sh` returns to write-and-print; `change-workflow.sh` returns to a silent `COMPLETE` with no lock and no origin check.
2. Delete `scripts/lib/audit-verdict.sh`, `scripts/tests/`, `.workflow/audit-verdict`, `.workflow/origin`, and `.workflow/lock/` if present. Nothing reads any of these after the revert; leaving them is harmless.
3. No data migration, no `.workflow/state` reset, no approval-hash invalidation — none of those formats changed (§9, spec §11).
4. Already-closed GitHub issues are **not** reopened by a rollback; reopen by hand if required. This is the only non-code-reversible effect of the change.

## 15. Feature-flag or containment strategy

No new flag or env toggle (unrequested surface). Containment is structural and now six independent conditions, all of which must hold to reach the GitHub write: TTY presence is no longer one of them (§1.5 removes that gate; it never gated the *write*, only the prompt); exact-word confirmation; run-id match; origin match (repo + issue, new); audit-hash match (new); verdict in `{READY, READY_WITH_NON_BLOCKING_ISSUES}`; and `USED_GH=1` with live `gh` auth. The pre-existing containment for spend (`WORKFLOW_BUDGET_*`) and for stage approval (`human_gate`) is unchanged and still applies to the chained run. The lock (§1.3) is not itself a containment condition on the GitHub write — it is a precondition on the driver *starting* at all, which indirectly protects every downstream check from cross-run interference.

## 16. Automated-test strategy

The repo has no test framework or CI (BASELINE §7); this plan does not add one. Three levels, up from CHANGE_PLAN's two:

- `scripts/tests/audit-verdict-test.sh` — extends CHANGE_PLAN's fixture set with AR-005 cases: a file whose last non-blank line is `READY` but preceded by a `NOT READY` finding (must classify `READY` — still last-line wins, now exact-match only); a last line reading `Rerun until READY` (must be `UNKNOWN` — not an exact phrase); a last line that's a markdown heading `## READY` (must classify `READY` after marker-stripping); a last line with two phrases concatenated (`UNKNOWN`); trailing blank lines after the verdict line (must still find the true last non-blank line); CRLF line endings (must not break exact-match). All of CHANGE_PLAN §16's original fixtures are retained.
- `scripts/tests/close-flow-test.sh` (new, AR-007) — hermetic, stubs `gh` and the reviewer command; drives the full close decision through every row of §12's error table and asserts exact stdout markers and exit codes for: READY→close, READY_WITH_NON_BLOCKING_ISSUES→close, NOT_READY→no close, UNKNOWN→no close, run-id mismatch→no close, origin mismatch→no close, audit-hash mismatch→no close, missing verdict file→no close, driver nonzero exit→no close + propagated status (specifically covering AR-008's 1/7/130 cases), curl-fallback (`USED_GH=0`)→skip message, `gh` unauthenticated→skip message, close command failing→nonzero exit + explicit message, decline at prompt→no driver/no close, lock held→refuse to start, foreign origin with non-empty state→refuse to seed.
- `for f in scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh; do bash -n "$f"; done` — must exit 0 for all (AC-7).

Not automatable here: anything requiring a live agent pipeline or a real GitHub write. Those are §18. The TTY-blocking behavior itself (§1.5) is exercised in `close-flow-test.sh` by feeding stdin from a pipe and asserting the process blocks until input arrives, rather than by asserting any TTY-detection branch, since none remains.

## 17. Regression-test strategy

Not a bug fix, so there is no pre-existing failing test to name. The regression surface (BASELINE §13) is covered by re-executing the BASELINE §8 command set verbatim and diffing against BASELINE §9 results, plus one new guard for the lock's effect on standalone use:

| Guard | Command | Expected |
|---|---|---|
| Arg contract, all scripts | BASELINE §8 lines 3-7 | identical output and exit codes |
| `--new` path unchanged (B-08) | `./scripts/from-issue.sh <n> --new` against a scratch checkout, diff stdout and the resulting `REQUIREMENTS.md` vs. the pre-change script | byte-identical |
| Syntax | `bash -n` × all scripts | exit 0 |
| Driver standalone (B-10) | `./scripts/change-workflow.sh --help`, `--version`, `bogus` | unchanged per `scripts/README.md:120` |
| Driver standalone, single run, no `STAGEGATE_ORIGIN_*` | `./scripts/change-workflow.sh` end to end on a scratch checkout | lock acquired/released transparently; no origin file written or checked; behavior otherwise identical to pre-change |

## 18. Manual-verification strategy

| ID | Check | Expected |
|---|---|---|
| M-01 | `from-issue.sh <n> --change`, decline at the prompt | file written, hint printed, driver not started, issue still OPEN (B-03) |
| M-02 | Same, press ENTER / type a wrong word / send EOF | treated as decline (§9) |
| M-03 | Same, piped stdin (no TTY) | prompt still appears on the pipe and blocks for input; providing the exact word on the pipe proceeds exactly as an interactive confirm would (§1.5, reversing CHANGE_PLAN's M-03) |
| M-04 | Confirm; let the driver reach `COMPLETE` with a `READY` audit | `.workflow/audit-verdict` holds this run's id, class, and matching hash; `.workflow/origin` names this issue; issue CLOSED with a comment; `gh issue view <n> --jq .state` == `CLOSED` (B-04, AC-3) |
| M-05 | Hand-edit `FINAL_AUDIT.md` to `NOT READY`, re-run only the audit stage, re-check | issue OPEN, explanatory message (B-05) |
| M-06 | Confirm, then decline an internal `human_gate` | driver exits 0; no close (B-06) |
| M-07 | Confirm with `PATH` stripped of `gh` at close time / `gh auth logout` | close skipped with a message, run still reports success (B-07, I-09) |
| M-08 | `from-issue.sh <n> --new` | unchanged output, no prompt, no close (B-08) |
| M-09 | Seed and advance issue A to `IMPLEMENT`; then seed issue B in the same checkout | `from-issue.sh` for issue B **refuses** to write `CHANGE_REQUEST.md` or prompt — prints the conflicting origin (issue A) and exits nonzero; issue A's in-progress state is untouched (replaces CHANGE_PLAN's warning-only M-09, per AR-001) |
| M-10 | Run each script from `/tmp` via absolute path | all still work (I-04), including the new `source` of the lib |
| M-11 | Start a driver run, then start a second `change-workflow.sh` against the same checkout while the first is mid-`FINAL_AUDIT` | second invocation refuses to start with a lock-held message naming the live PID; first invocation completes normally (AR-003) |
| M-12 | Precreate a stale `READY` `FINAL_AUDIT.md`; stub the reviewer command to exit 0 without writing output; run `FINAL_AUDIT` | hard failure — `require_file` sees the file absent (removed beforehand) and stops before any verdict is written or any close is attempted (AR-002) |
| M-13 | Decline an internal `human_gate` after confirming via `from-issue.sh`, then rerun `from-issue.sh <n> --change` for the same issue without editing `CHANGE_REQUEST.md` | seed step is skipped (origin already matches); prompt reappears; confirming resumes the driver from its saved state; the original issue closes exactly once on eventual `READY` (AR-004) |

## 19. Observability changes

Additive stdout only: the seeded-file echo and pre-flight warnings before the prompt (or the "resuming existing seed" notice when the seed step is skipped, §1.1); one `Audit verdict: <class>` line in `FINAL_AUDIT`; one close/skip/failure line at the end; a lock-held refusal line naming the blocking PID (§1.3); an origin-mismatch refusal line naming the conflicting issue (§1.1). `.workflow/audit-verdict` doubles as the durable record of what the last audit concluded, now including the hash of the exact file it judged. `.workflow/origin` doubles as the durable record of which issue currently owns the checkout. No logging framework, no new log files, no change to `.workflow/logs/` or `cost.tsv`.

## 20. Implementation sequence

Reordered from CHANGE_PLAN §20 so every safety mechanism the review demanded lands *before* any code path that can reach `gh issue close`.

1. Write `scripts/tests/audit-verdict-test.sh` first (all cases fail — the lib does not exist), including the AR-005 exact-match fixtures, then `scripts/lib/audit-verdict.sh` until it passes.
2. `change-workflow.sh`: source the lib; add the lock acquire/release (§1.3) around `main`; add the origin preflight check and `ANALYZE`-time (re)write (§1.1). `bash -n`; confirm `--help`/`--version`/unknown-arg unchanged; confirm a standalone single run is unaffected (§17 new guard); confirm M-11 (lock contention) manually.
3. `change-workflow.sh`: `FINAL_AUDIT` — `rm -f FINAL_AUDIT.md` before `run_codex`; write `.workflow/audit-verdict` with the third hash field. Confirm M-12 (stale-audit rejection) manually before proceeding.
4. `from-issue.sh`: `USED_GH` capture, origin check before `write_change_request`, `confirm_and_run_workflow()` with the pre-flight display, no-TTY-precondition prompt (§1.5), explicit status capture (§1.7), driver invocation with `STAGEGATE_RUN_ID` and `STAGEGATE_ORIGIN_REPO`/`STAGEGATE_ORIGIN_ISSUE` exported. Verify M-01/M-02/M-03/M-08/M-09/M-13 before writing any close code.
5. `from-issue.sh`: `close_issue_if_ready()` — run-id match, origin match, audit-hash match, `USED_GH` + live-auth checks, then `gh issue close --repo "$OWNER/$REPO" --comment` with the class and pointers to `FINAL_AUDIT.md` and `.workflow/change.diff`.
6. Write `scripts/tests/close-flow-test.sh` (AR-007) against the now-complete functions; it must cover every row of §12.
7. Docs: `README.md:114-133`, `scripts/README.md:63-82`.
8. Full check pass: `bash -n` × all, BASELINE §8 replay, M-01…M-13.

Steps 1-5 contain no GitHub write except at the very end of step 5; every safety mechanism from the review (lock, origin, fresh-audit removal, exact-match classifier, blocking prompt, explicit status) is in place and independently testable before that write is reachable.

## 21. Scope cuts under time pressure

Cut in this order:

1. Close-comment richness — reduce to the verdict class alone, dropping the `change.diff` pointer (AC-3 requires only that a comment exist).
2. `README.md` prose polish, keeping `scripts/README.md` accurate.
3. `scripts/tests/close-flow-test.sh`'s coverage of the lock-contention and stale-audit rows specifically (M-11/M-12) may be deferred to manual-only if the hermetic stub for a second concurrent process proves disproportionately complex — the lock and `rm -f` mechanisms themselves are never cut, only their automated (vs. manual) verification.

Never cut, under any time pressure: the confirmation gate (I-07); the run-id match, origin match, and audit-hash match (I-08, now three independent checks per AR-001/AR-002); the lock (AR-003); the `USED_GH`/auth guard (I-09); the exact-match classifier and its test (AR-005); the explicit status capture (AR-008); the blocking (non-`[ -t 0 ]`) prompt (AR-006). These eight items are the entire adversarial-review response — cutting any of them re-opens the finding it was written to close.

## 22. Risks and unresolved questions

- **Stale-state resume — narrowed, not eliminated.** The origin file (§1.1) proves *whose* checkout this is at the (repo, issue) granularity, closing AR-001's wrong-issue-close scenario and AR-004's provenance loss. It does **not** prove the resumed state reflects the same *content* of `CHANGE_REQUEST.md` the human last approved inside the driver — if a human edits `CHANGE_REQUEST.md` by hand between runs for the *same* issue without going through `from-issue.sh`, the driver's own `verify_approval()`/SHA-256 pinning (I-02, unmodified) is still the mechanism that catches that, exactly as it does today for a solitary human operator. This plan does not add a second hash check on `CHANGE_REQUEST.md` itself — doing so would duplicate I-02's existing enforcement rather than fix a gap.
- **Concurrent runs — closed for this checkout, not across checkouts.** The lock (§1.3) is per-checkout (`.workflow/lock` lives inside the repo's own `.workflow/`). Two *separate* clones of the repo each running a driver against the *same* GitHub issue are not mutually excluded by this lock; only the origin+run-id+hash triad at close time (§1.1/§1.2) would catch a resulting cross-clone collision, and only if their identities happen to differ. Cross-clone concurrent use of `from-issue.sh --change` against one issue is out of scope for this change; flagged, not solved.
- **Uncommitted-work capture.** `README.md:106` tells the human to commit or stash before starting the driver, because `IMPLEMENT` records `git diff` of the whole tree. Chaining removes the natural pause for that step; the pre-flight reminder is the only mitigation. Unchanged from CHANGE_PLAN §22 — none of the review's findings addressed this directly.
- **Verdict parsing brittleness — reduced, not zero.** The exact-last-line rule (§1.4) closes every fixture the reviewer named, but still depends on `FINAL_AUDIT.md`'s last non-blank line being exactly one of the three phrases per `prompts/change/final-audit.md:54-58`. A reviewer CLI that appends a trailing blank-then-signature block whose last non-blank line is *not* the verdict yields `UNKNOWN` — safe (no close), but the feature silently stops working. Not fixable from this side without editing the prompt, which §12 (spec) forbids.
- **Trust-surface change.** `from-issue.sh` goes from one local write plus a read-only fetch to a long-running, budget-spending, GitHub-mutating, lock-acquiring script (BASELINE §16). Accepted by the spec; the six-condition containment in §15 is the answer, now including origin and audit-hash matches beyond CHANGE_PLAN's original four.
- **RESOLVED — comment authorship.** Retained from CHANGE_PLAN §22 unchanged: "Closed by stagegate: change workflow completed with FINAL_AUDIT.md verdict `<CLASS>`. See FINAL_AUDIT.md and .workflow/change.diff in the working tree." No review finding touched this; confirmed at plan approval.
- **RESOLVED — `scripts/lib/` precedent.** Retained from CHANGE_PLAN §22: kept because it is the only way to get automated coverage of the fail-closed classifier. The review's own AR-007 finding independently argues for *more*, not less, automated test surface (`scripts/tests/close-flow-test.sh`), reinforcing rather than undercutting this precedent.
- **NEW — stale-lock false negative.** The lock's liveness check (`kill -0` on the recorded PID) can be fooled if the OS has since reused the dead process's PID for an unrelated process before the next `change-workflow.sh` invocation checks it — a live PID that is not actually the lock holder would be misread as "still holds the lock," causing an unnecessary refusal (safe direction: a false refusal, never a false proceed). No false-*proceed* failure mode exists here; flagged for completeness, not blocking.

## Change-impact table

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/lib/audit-verdict.sh` | new pure classifier, exact-last-line matching | machine-readable verdict (B-10, I-08); exactness per AR-005 | none — new file, no existing caller | `scripts/tests/audit-verdict-test.sh` (extended fixtures) |
| `scripts/tests/audit-verdict-test.sh` | new, extended | first automated check in the repo; AR-005 coverage | none | self |
| `scripts/tests/close-flow-test.sh` | new | AR-007 end-to-end close-decision coverage | none — new file | self |
| `scripts/change-workflow.sh` `main` | acquire/release `.workflow/lock` | serialize the whole run (AR-003) | low — additive wrapper around existing `main`; released via `EXIT` trap | M-11 |
| `scripts/change-workflow.sh` preflight | origin check before dispatch | refuse foreign/mismatched state (AR-001, AR-004) | **medium** — a wrong comparison here either over-refuses (annoying) or under-refuses (re-opens AR-001); must be exercised against both same-origin and cross-origin fixtures | M-09, M-13; close-flow-test.sh |
| `scripts/change-workflow.sh` `ANALYZE` | (re)write `.workflow/origin` on fresh/`COMPLETE` start | claim the checkout for the current issue | low — additive | M-04, M-13 |
| `scripts/change-workflow.sh` `FINAL_AUDIT` | `rm -f FINAL_AUDIT.md` before `run_codex`; write widened `.workflow/audit-verdict` | eliminate stale-audit acceptance (AR-002); bind verdict to file content | low — additive, before the existing `run_codex`, after which behavior is unchanged | M-12; close-flow-test.sh |
| `scripts/change-workflow.sh` header | `source` the lib | reuse the classifier | low — must be self-relative or breaks I-04 | M-10; `--help`/`--version` replay |
| `scripts/from-issue.sh` fetch block | set `USED_GH` | close requires `gh`, not `curl` (I-09) | low — flag only, fetch logic unchanged | M-07 |
| `scripts/from-issue.sh` `write_change_request` | drop the trailing `Run:` hint; gate on origin check; skip rewrite on same-origin resume | hint moves to the decline path (B-01/B-03); AR-001/AR-004 | **medium** — a wrong same-origin comparison could either skip a legitimate rewrite or wrongly overwrite an in-progress unrelated issue's seed | M-01, M-09, M-13 |
| `scripts/from-issue.sh` new confirm fn | prompt (no TTY precondition) + explicit status capture + driver invocation + write `.workflow/origin` | B-01, B-02, I-07; AR-006, AR-008 | **medium** — bare `read` on EOF and the status-capture form are both live traps if implemented sloppily | M-01, M-02, M-03; close-flow-test.sh |
| `scripts/from-issue.sh` new close fn | `gh issue close --comment`, gated on run-id + origin + audit-hash + `USED_GH`/auth | B-04, I-05 RELAXED; AR-001, AR-002 | **high** — only irreversible effect in the change, now with three independent gates instead of one | M-04…M-07; close-flow-test.sh |
| `scripts/from-issue.sh` dispatch | call the two fns in `change)` only | keep `--new` untouched (B-08) | medium — a misplaced call would hit `--new` | M-08, `--new` byte-diff |
| `README.md`, `scripts/README.md` | document the new flow, including lock/origin refusal messages and the blocking non-TTY prompt | BASELINE §12; docs currently describe a two-step handoff | none functional | M-01…M-13 read against the docs |

## Traceability

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| AC-1 seed → prompt → run | B-01, B-02 | I-07 | `from-issue.sh` confirm fn | `bash -n`; close-flow-test.sh | M-04 |
| AC-2 decline runs nothing | B-03 | I-07 | `from-issue.sh` confirm fn | close-flow-test.sh | M-01, M-02, M-03 |
| AC-3 READY → closed + comment | B-04, B-10 | I-05, I-06, I-08, I-10, I-11 | `change-workflow.sh` `FINAL_AUDIT`; `from-issue.sh` close fn; classifier; origin file; lock | classifier test; close-flow-test.sh | M-04 |
| AC-4 NOT READY / incomplete → open | B-05, B-06 | I-08 | classifier; run-id match | classifier test (`NOT_READY`, `UNKNOWN`); close-flow-test.sh | M-05, M-06, M-09 |
| AC-5 curl fallback → skip + message | B-07 | I-09 | `USED_GH` + auth guard | close-flow-test.sh | M-07 |
| AC-6 `--new` unchanged | B-08 | I-04 | dispatch `case` | `bash -n`; `--new` byte-diff | M-08 |
| AC-7 `bash -n` + arg contract | B-09 | I-04 | all scripts | `bash -n` × all; BASELINE §8 replay | M-10 |
| Wrong-issue close prevented | — | I-11 (NEW) | origin file; preflight check; `from-issue.sh` origin gate | close-flow-test.sh | M-09, M-13 |
| Stale audit cannot be accepted | — | I-08 (NEW, strengthened) | `rm -f` before `run_codex`; audit-hash field | classifier test; close-flow-test.sh | M-12 |
| Concurrent runs cannot cross-contaminate | — | I-10 (NEW) | `.workflow/lock` | close-flow-test.sh | M-11 |
| Non-interactive callers hit the approved break | B-01, B-02 | I-07 | `from-issue.sh` confirm fn (no TTY precondition) | close-flow-test.sh | M-03 |
| Driver failure status is never inverted | B-06 | I-08 | explicit `status=0; cmd \|\| status=$?` | close-flow-test.sh | M-06 |
| Existing gates unweakened | — | I-01, I-02, I-03 | `human_gate`, `verify_approval`, `run_codex` call sites — not modified | — | M-06 (declined gate still halts) |

New invariants added by this update (beyond CHANGE_SPEC's I-01–I-09, all serving CHANGE_SPEC's existing I-08 acceptance intent rather than replacing it):

| ID | Status | Invariant | Scope | Enforcement point | Verification |
|---|---|---|---|---|---|
| I-10 | NEW | Only one `change-workflow.sh` run may hold a given checkout's `.workflow/` at a time | `change-workflow.sh` `main` | `.workflow/lock` (`mkdir`-atomic, PID-stamped) | M-11; close-flow-test.sh |
| I-11 | NEW | A resumed or auto-invoked run may not act on `.workflow/state` unless it can prove that state belongs to the current (repo, issue) | `change-workflow.sh` preflight; `from-issue.sh` seed gate | `.workflow/origin` + `STAGEGATE_ORIGIN_REPO`/`ISSUE` comparison | M-09, M-13; close-flow-test.sh |

Bug-fix regression test: not applicable — this is a Feature (CHANGE_SPEC §1); there is no pre-existing failing behavior to pin. The nearest equivalent is the classifier's `NOT_READY`/`UNKNOWN` fixtures and the new close-flow-test.sh's negative-path assertions, both of which must pass before the close code at implementation step 5 is written.
