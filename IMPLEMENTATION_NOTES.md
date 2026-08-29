# Implementation Notes

Approved scope: UPDATED_CHANGE_PLAN.md §20 steps 1-8. All steps implemented; no
scope cuts from §21 were taken.

## Pre-existing uncommitted work (untouched)

`ADVERSARIAL_REVIEW.md`, `BASELINE_REPORT.md`, `CHANGE_PLAN.md`,
`CHANGE_REQUEST.md`, `CHANGE_SPEC.md`, `UPDATED_CHANGE_PLAN.md` were modified in
the working tree before implementation began and were not written to.
`.workflow/` was not written to (state remained `IMPLEMENT` throughout; every
test runs against a scratch checkout under `mktemp -d`).

## Files changed

| File | Purpose | Plan step | Behavior / invariant |
|---|---|---|---|
| `scripts/lib/audit-verdict.sh` (new) | `classify_audit_verdict()` — last-non-blank-line, exact-phrase, fail-closed classifier for `FINAL_AUDIT.md` | §20.1, §1.4 | B-10; I-08; AR-005 |
| `scripts/tests/audit-verdict-test.sh` (new) | 26 fixture assertions for the classifier, including the AR-005 malformed-input set | §20.1, §16 | I-08 |
| `scripts/tests/close-flow-test.sh` (new) | 99 hermetic assertions over the whole close decision, the driver lock, the origin preflight, and audit freshness | §20.6, §1.6 | B-01…B-07, I-08…I-11 |
| `scripts/change-workflow.sh` — path constants | adds `LOCK_DIR`, `ORIGIN_FILE`, `VERDICT_FILE` beside the existing `.workflow` paths | §9 | — |
| `scripts/change-workflow.sh` — after `hash_file` | sources the classifier lib self-relative | §4 | I-04 |
| `scripts/change-workflow.sh` — `acquire_lock`/`release_lock` | `mkdir`-atomic, PID-stamped exclusive lock; stale lock cleared on a dead PID; released by the `EXIT` trap | §1.3 | I-10 (NEW) |
| `scripts/change-workflow.sh` — `origin_preflight`/`write_origin` | refuses to act on in-flight state that cannot be proven to belong to `STAGEGATE_ORIGIN_REPO`/`ISSUE`; skipped entirely for standalone runs | §1.1 | I-11 (NEW), B-10 |
| `scripts/change-workflow.sh` — before the state loop | `acquire_lock` then `origin_preflight`, once, before any state dispatch | §1.1, §1.3 | I-10, I-11 |
| `scripts/change-workflow.sh` — `ANALYZE` | `write_origin` claims the checkout on a fresh run | §1.1 | I-11 |
| `scripts/change-workflow.sh` — `FINAL_AUDIT` | `rm -f FINAL_AUDIT.md` before `run_codex`; writes `.workflow/audit-verdict` as `<run-id>TAB<class>TAB<sha256>`; echoes the class | §1.2 | B-10, I-06, I-08 |
| `scripts/from-issue.sh` — fetch block | `USED_GH=1` only when `fetch_with_gh` produced the JSON | §4 | B-07, I-09 |
| `scripts/from-issue.sh` — new functions | `workflow_state`, `origin_line`, `this_origin`, `run_in_flight`, `check_origin_or_refuse`, `seed_is_current`, `confirm_and_run_workflow`, `close_issue_if_ready` | §20.4, §20.5 | B-01…B-07, I-05 RELAXED, I-07, I-08, I-09, I-11 |
| `scripts/from-issue.sh` — `write_change_request` | drops the trailing `Run:` hint (it moved to the decline path) | §4 | B-01 |
| `scripts/from-issue.sh` — dispatch | `change)` runs the origin gate, seeds or skips, then confirms/runs/closes; `new)` untouched | §4 | B-08 |
| `README.md` | documents confirm → auto-run → auto-close, the blocking non-TTY prompt, and the lock/origin refusals | §20.7 | — |
| `scripts/README.md` | same, plus the `gh`-required-for-close note, the four close preconditions, and the `.workflow` file contract | §20.7 | — |

Containment reached as planned: `gh issue close` is called from exactly one
place, behind exact-word confirmation, driver exit 0, run-id match, origin
match, audit-hash match, verdict class, `USED_GH=1`, and live `gh auth`.

## Deviations from the approved plan

| # | Plan text | What was done | Why |
|---|---|---|---|
| D-1 | §4: "start of `main`, before state dispatch" | Lock and preflight placed immediately before the `while true` state loop, after the `WORKFLOW_TRACK` validation | `change-workflow.sh` has no `main()`; this is the equivalent point — before any state is read, dispatched, or written. Verified by `preflight-origin-mismatch`, which leaves `.workflow/state` untouched. |
| D-2 | §1.1: the absent-origin refusal belongs to the driver preflight; `from-issue.sh` refuses only on a *different* origin | `from-issue.sh` also refuses when state is in flight and `.workflow/origin` is absent | `confirm_and_run_workflow` writes `.workflow/origin` before invoking the driver, so without this the seeder would manufacture the very ownership proof the driver's absent-origin check looks for, re-opening AR-001. The driver-side check is retained unchanged as an independent backstop for direct invocation (covered by `preflight-origin-absent`). |
| D-3 | §1.2: "`require_file` now fails on absence, not just emptiness" | `require_file` left unmodified | It already fails on absence: `[[ ! -s "$1" ]]` is true for a missing file. The `rm -f` before `run_codex` was the only change needed, and it makes existence the freshness proof as intended. Asserted by `stale-audit-rejected`. |
| D-4 | §1.5 / §12: the prompt blocks on `read` for non-interactive callers | Prompt text is `printf`ed before a bare `read` instead of being passed to `read -p` | Bash suppresses a `-p` prompt when stdin is not a terminal, so `read -p` would have blocked *silently* on a pipe — satisfying "blocks" but not M-03's "prompt still appears on the pipe." Blocking semantics are unchanged. |
| D-5 | §1.6: the test sources `from-issue.sh` "not the full CLI" | Added a `STAGEGATE_FROM_ISSUE_SOURCE_ONLY=1` env hook that returns after the function definitions | Sourcing the script otherwise executes the CLI, including a live GitHub fetch, which is not hermetic. It is an env hook, not a CLI flag: the argument contract (B-09, `scripts/README.md:115-129`) is unchanged and re-verified. |
| D-6 | §21.3 allowed deferring the M-11/M-12 rows of `close-flow-test.sh` to manual-only | Both are automated (`lock-held-by-live-pid`, `lock-stale-pid-cleared`, `stale-audit-rejected`) | The stubs proved cheap: the lock and preflight refuse before any agent call, and a `/usr/bin/true` reviewer reproduces the no-op-reviewer case. No deferral was needed. |

No RELAXED or REMOVED invariant beyond the already-approved I-05 was introduced.
No test was weakened, no fixture or expected output was updated to fit the
implementation, and no unrelated file was reformatted.

## Unresolved concerns

- **`.gitignore` needed no change.** `.workflow` is ignored wholesale
  (`.gitignore:1`), so `origin`, `audit-verdict`, and `lock/` are already
  covered; §9's "gitignored alongside `state`" is satisfied without an edit.
- **M-04 and M-05 are not automatically verified end to end.** A real close
  against a live issue requires a full agent pipeline run; `close-flow-test.sh`
  covers the decision logic with a stubbed `gh`, but the first real `gh issue
  close` will happen on this change's own run. Carried into
  `CHANGE_TEST_REPORT.md` as an untested area.
- **Cross-clone concurrency remains open** (UPDATED_CHANGE_PLAN §22): the lock
  is per-checkout, so two clones driving the same issue are not mutually
  excluded. Unchanged by implementation; flagged, not solved.
- **Stale-lock PID reuse** (§22): a recycled PID reads as a live holder and
  causes a false refusal. Safe direction only; no false proceed.
- **Verdict parsing still depends on `prompts/change/final-audit.md`** ending
  its output with the phrase alone on the last non-blank line. A reviewer that
  appends a signature block yields `UNKNOWN` — no close, feature silently
  inert. Editing the prompt is out of scope per CHANGE_SPEC §12.
