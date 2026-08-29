# Implementation Notes

Implements UPDATED_CHANGE_PLAN.md items **B**, **C**, **D**, **E**, with the
AR-001/002/003/004/008 guards. Item **A** (opus vs. kimi) is not implemented and
remains open — see "Unresolved concerns".

## Pre-implementation checks

| Check | Result |
|---|---|
| Version-control status inspected before editing | `ADVERSARIAL_REVIEW.md`, `BASELINE_REPORT.md`, `CHANGE_PLAN.md`, `CHANGE_REQUEST.md`, `CHANGE_SPEC.md`, `UPDATED_CHANGE_PLAN.md` were already uncommitted. None is in "files expected to change"; none was touched. |
| Uncommitted work in any "file expected to change" | None. Nothing was overwritten. |
| Baseline re-run before any edit | `close-flow-test.sh` 99/99, `audit-verdict-test.sh` 26/26 = 125/125 in a sanitized shell. Matches BASELINE_REPORT.md §9. |
| Approved plan still matches the repository | Yes. All line anchors in UPDATED_CHANGE_PLAN §4 resolved to the code they name. |
| `timeout`/`gtimeout` availability (AR-008) | Both present (`/opt/homebrew/bin/timeout`, `/opt/homebrew/bin/gtimeout`). AR-008 does not degrade here. |

## Files changed

| File | Purpose of change | Approved-plan step | Behavior / invariant |
|---|---|---|---|
| `scripts/lib/state.sh` (new) | `state_read` (tolerant, strips a leading `<digits>:`), `state_issue`, `state_write` (prefixes when an issue is known). One parser, so the two `!= "COMPLETE"` comparison sites cannot drift. | §20 step 2 | BEH-B (MODIFY); INV-1 not weakened — the prefix is never read as an identity |
| `scripts/lib/issue-close.sh` (new) | The single INV-3 gate: `issue_close_if_ready`, plus `origin_field`, `origin_fetch_method`, `issue_close_timeout_cmd`, and the AR-004 `state_origin_agree` check. Carries the AR-001 freshness, AR-003 provenance, AR-002 ownership preconditions and the AR-008 timeout. | §20 steps 6, 6a, 7, 7a, 7b | BEH-D (MODIFY); INV-3 (STRENGTHENED) |
| `scripts/change-workflow.sh` | Sources both libs; `set_state`/`get_state` delegate to the lib; `current_issue` resolves the issue from `STAGEGATE_ORIGIN_ISSUE` then `.workflow/origin`; `origin_preflight` gains the AR-004 corruption check and field-based origin comparison; `write_origin` carries forward an existing provenance field; `ORIGIN_BOUND`/`VERDICT_WRITTEN_THIS_RUN` computed; `close_origin_issue_if_ready` added and called at `COMPLETE`; `WORKFLOW_CLOSE_ISSUE` and `MARKER_FILE` added. | §20 steps 2, 6a, 7, 7a | BEH-B, BEH-D; INV-1, INV-3 |
| `scripts/from-issue.sh` | Sources both libs; `workflow_state` reads through `state_read`; `origin_matches_this` replaces whole-line origin equality; seed gate gains the AR-004 check and the C manual-clear guidance; `write_origin` writes the third fetch-provenance field; `close_issue_if_ready` reduced to a wrapper (marker check, `USED_GH` guard, shared gate, `exit 1` only on a failed close). | §20 steps 2, 5, 6, 6a | BEH-B, BEH-C (PRESERVE + message), BEH-D; INV-1, INV-3, INV-5 (unchanged — still refuse, never zero) |
| `scripts/tests/close-flow-test.sh` | `new_case` copies all of `scripts/lib/*.sh`; `run_driver` exports `GH_LOG_FILE` and strips ambient `STAGEGATE_ORIGIN_*`/`STAGEGATE_RUN_ID`; `gh` stub gains `FAKE_GH_CLOSE_SLEEP`; driver stub gains `FAKE_DRIVER_CLOSED_MARKER`/`FAKE_DRIVER_MARKER_TEXT`; `setup_audit_stage` and five new assertion helpers; 24 new cases. | §20 steps 1, 4, 5, 7, 7a, 7b | Coverage for B, C, D, E; R-4 |
| `README.md` | State-file grammar, `.workflow/issue-closed`, `WORKFLOW_CLOSE_ISSUE`. | §20 step 8 | CHANGE_SPEC §8 anti-drift |
| `scripts/README.md` | Driver-side close and its preconditions, origin third field, marker file, state grammar, corruption refusal, manual-clear guidance. | §20 step 8 | CHANGE_SPEC §8 anti-drift |

Not modified, as approved: `scripts/stagegate.sh` (AR-007/AR-009 — dropped
outright, not deferred), `scripts/workflow.sh`, `scripts/lib/audit-verdict.sh`,
`scripts/codex-*.sh`, `prompts/**`, `QUICK_START.md` (verified: its bare
`echo REQUIREMENTS > .workflow/state` instruction still holds), all model /
effort / turn / tool / CLI defaults, the cost ledger, the lock implementation,
`verify_approval`, `scripts/tests/audit-verdict-test.sh`, and every
reviewer-owned artifact.

## Deviations from the approved plan

| # | Deviation | Reason |
|---|---|---|
| D-1 | AR-003's refusal reuses the existing verbatim string `"Issue was fetched over the unauthenticated curl fallback, which cannot close issues."` instead of adding a new distinct reason (UPDATED §19 anticipated one new reason per guard). | The condition is identical to the one that string already names, and UPDATED §4 forbids changing existing strings. One message per condition keeps the single-gate property; two would let a reader think there are two different rules. Test-visible consequence: the pre-existing `curl-fallback-skips-close` and the new `curl-fallback-driver-side-skips-close` assert the same text, distinguished by which entry point produced it. |
| D-2 | The AR-001 freshness signal is computed at process start (immediately after `origin_preflight`, before the state loop), not "at `ANALYZE` entry" as UPDATED §4/§20-7 word it. | A run that starts mid-pipeline — the exact case item D exists for — never enters `ANALYZE`, so an `ANALYZE`-only computation would leave the signal undefined there. Process start strictly satisfies R-9's requirement ("once, before this run performs any state write") for every entry point. |
| D-3 | `issue_close_if_ready` takes 11 positional arguments; CHANGE_PLAN §4 specified 8. | The 3 added are exactly the inputs UPDATED §4 requires (`origin_bound`, `run_owns_verdict`, `fetch_method`). |
| D-4 | New environment variable `STAGEGATE_CLOSE_TIMEOUT` (default `30`), not named in the plan. | Makes AR-008's deadline testable hermetically; without it the timeout case would need a 30-second test. Additive, defaulted, documented in the lib header. |
| D-5 | `preflight-prefixed-complete-passes` uses an origin foreign by **repo** (`other/repo TAB 42`) rather than foreign by issue (`other/repo TAB 99`) as CHANGE_PLAN §16 wrote it. | With AR-004 in place, a prefixed state beside an origin naming a *different issue* is now the corruption case (exit 1), which directly contradicts that row's expected exit 0. The revised fixture keeps the row's assertion and its fail-first property intact (verified below); the issue-disagreement combination has its own case, `state-origin-issue-mismatch-refused`. |
| D-6 | `.workflow/origin`'s third field is TAB-delimited. | UPDATED §9's explicit grammar is `<owner/repo> TAB <issue> [TAB <gh\|curl>]`; the AR-003 disposition row's "space-delimited" wording conflicts with it and with fields 1–2. §9 was followed. |
| D-7 | Origin comparisons in `origin_preflight`, `from-issue.sh`'s seed gate, and the close gate changed from whole-line equality to field-by-field equality. | Mechanically required by the third field: whole-line equality would reject every 3-field origin file. Implied by §8/§9 but not spelled out. Identity is still fields 1–2 only; provenance is deliberately not part of it. |
| D-8 | `from-issue.sh`'s `this_origin` was removed and its inline origin write became a `write_origin` function. | `this_origin` is dead code after D-7; `write_origin` is the function name UPDATED §4 assigns the provenance write. |
| D-9 | The `.workflow/issue-closed` marker is written by the shared gate, so a `from-issue.sh` close now writes it too (CHANGE_PLAN §6 described it as driver-written). | Keeps the write in the one place that knows a close succeeded, and makes a repeated `from-issue.sh` close idempotent for the same reason a driver close is. |
| D-10 | `change-workflow.sh`'s `write_origin` carries forward an existing third field when it re-claims the same `(repo, issue)`, and otherwise writes two fields. | The driver never fetches an issue, so it cannot honestly originate a `gh` provenance claim; without carry-forward it would erase `from-issue.sh`'s claim at `ANALYZE` and break the main chained path. Writing nothing (rather than `curl`) leaves it fail-closed by AR-003's own rule. |

No approved requirement was changed, no invariant was relaxed, no test was
weakened, and no snapshot, fixture, or expected output was silently updated.
Every pre-existing asserted string in `close-flow-test.sh` is preserved verbatim.

## Unresolved concerns

1. **CR Motivation-A (opus vs. kimi) is not delivered and remains open.** This
   is a partial delivery of the change request by design (CHANGE_SPEC §1/§4-A,
   AR-005 disposition). B, C, D, E are complete; A is blocked on the human.
2. **AR-007 (deferred) is not mitigated.** `stagegate.sh` and
   `change-workflow.sh` still share `.workflow/state` and `FINAL_AUDIT.md` with
   no cross-driver mutex. This change neither creates nor worsens it, and does
   not increase `stagegate.sh`'s coupling. A follow-up CR is recommended.
3. **R-10 stands.** A hand-edited `.workflow/origin` claiming `gh` provenance it
   never had is indistinguishable from legitimate operator recovery.
4. **AR-008 degrades on a host with neither `timeout` nor `gtimeout`** — the
   close reverts to CHANGE_PLAN §11's unbounded assumption. Not the case in this
   environment; the automated case self-skips with a printed NOTE if it ever is.
5. **MV-1 through MV-8 have not been executed.** They belong to Stage 7 and
   `VERIFICATION_REPORT.md`, against the reviewer's `MANUAL_CHECKLIST.md`.
6. **Working-tree staging.** Several files (including the pre-existing artifact
   edits) appear staged in `git status`; nothing in this stage ran `git add`, and
   no file outside the approved list was modified. Left as found, per core
   rule 13.
