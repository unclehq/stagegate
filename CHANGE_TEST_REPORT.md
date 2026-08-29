# Change Test Report

All commands were run from the repository root with the three ambient stagegate
variables stripped (`env -u STAGEGATE_ORIGIN_REPO -u STAGEGATE_ORIGIN_ISSUE
-u STAGEGATE_RUN_ID`), per BASELINE_REPORT.md §10. Every line below was
executed; nothing is reported from memory.

## Checks

| Check | Command | Result |
|---|---|---|
| Baseline (before any edit) | `bash scripts/tests/close-flow-test.sh` | PASS — `close-flow-test.sh: 99 checks passed` |
| Baseline (before any edit) | `bash scripts/tests/audit-verdict-test.sh` | PASS — `audit-verdict-test.sh: 26 checks passed` (125/125 total, matches BASELINE_REPORT.md §9) |
| Targeted tests | `bash scripts/tests/close-flow-test.sh` | PASS — `close-flow-test.sh: 181 checks passed` (99 pre-existing + 82 new, from 24 new cases) |
| Regression tests | `bash scripts/tests/close-flow-test.sh` (cases `seed-gate-prefixed-complete-reseeds`, `preflight-prefixed-complete-passes`) | PASS — and both FAIL against a naive `state_read` that does not strip the prefix (fail-first evidence below) |
| Full test suite | `bash scripts/tests/close-flow-test.sh && bash scripts/tests/audit-verdict-test.sh` | PASS — 181 + 26 = **207 checks passed**, 0 failed |
| Formatting | N/A (no formatter in this repo; bash only, no `shfmt` configured or committed) |
| Compiler / type checker | `bash -n` on `scripts/change-workflow.sh`, `scripts/from-issue.sh`, `scripts/lib/state.sh`, `scripts/lib/issue-close.sh`, `scripts/tests/close-flow-test.sh` | PASS — all five parse clean (bash has no compile step; this is the closest equivalent) |
| Linting | NOT RUN — `shellcheck` is not installed in this environment (`command -v shellcheck` empty). It is also not wired into the repo or CI, so this is not a regression in coverage |
| Integration tests | `bash scripts/tests/close-flow-test.sh` (end-to-end hermetic driver runs: all `direct-run-*`, `state-*`, `preflight-*`, `lock-*`, and confirm-gate cases) | PASS — included in the 181 |
| Frontend build | N/A (no frontend; the repo is bash drivers only, BASELINE_REPORT.md §2) |
| Migration tests | `bash scripts/tests/close-flow-test.sh` (cases `state-bare-still-read`, `state-no-origin-stays-bare`, `legacy-two-field-origin-skips-close`) | PASS — a bare pre-change `.workflow/state` still dispatches and completes; a two-field pre-change `.workflow/origin` is read without error and fails closed at the close gate |
| Rollback test | `git archive HEAD \| tar x -C /tmp/sg-rollback` then both suites in that tree | PASS — `close-flow-test.sh: 99 checks passed`, `audit-verdict-test.sh: 26 checks passed`. Reverting restores the exact 125/125 baseline with no residue |
| Rollback (kill switch) | `bash scripts/tests/close-flow-test.sh` (case `direct-run-close-flag-off`) | PASS — `WORKFLOW_CLOSE_ISSUE=0` disables the whole driver-side close, no `gh` call, no marker, exit 0 |
| Performance checks | N/A (CHANGE_SPEC §10: no performance requirement stated or implied; the change adds local file reads and one already-existing network call) |
| Security checks | `bash scripts/tests/close-flow-test.sh` (AR-001/003 guard cases) + manual review of the gate | PASS — see "Security" below |
| Newly introduced warnings | `bash -n` and both suites | None. No new warning text on any path |
| Pre-existing failures | — | None carried in. The 4 failures BASELINE_REPORT.md §10 describes are the ambient-env artifact; `run_driver` now strips those three variables (approved R-4 fix), so the suite is green from a live stagegate session too |
| Untested areas | — | See "Untested areas" below |

## Fail-first evidence (acceptance criterion 5)

Each guard was removed in a throwaway copy of the tree and both suites re-run.
Every guard has at least one case that fails without it.

| Guard | Neutered as | Failing case(s) |
|---|---|---|
| AR-001 freshness | `origin_bound` check made unconditional | `direct-run-stale-origin-fresh-state-skips-close` (3 checks) |
| AR-002 sentinel | recorded `-` compared against `${STAGEGATE_RUN_ID:--}` (the natural naive form) | `direct-run-stale-sentinel-run-id-no-retry` (2 checks) |
| AR-002 retry | retry branch removed | `direct-run-close-retries-on-rerun` (3 checks) |
| AR-003 provenance | `fetch_method` check made unconditional | `curl-fallback-driver-side-skips-close`, `legacy-two-field-origin-skips-close`, and the pre-existing `curl-fallback-skips-close` (8 checks) |
| AR-004 corruption | `state_origin_agree` prefix read stubbed to empty | `state-origin-issue-mismatch-refused` (4 checks) |
| AR-008 timeout | `timeout`/`gtimeout` lookup stubbed to empty | `direct-run-close-timeout-treated-as-failure` (3 checks) |
| R-1 (BEH-B) | `state_read` no longer strips the prefix | `seed-gate-prefixed-complete-reseeds`, `preflight-prefixed-complete-passes`, `state-prefix-written`, and 12 further cases (34 checks) |

## Protected-file verification (acceptance criterion 4)

`git diff HEAD --stat` over `scripts/stagegate.sh`, `scripts/workflow.sh`,
`scripts/lib/audit-verdict.sh`, `scripts/codex-review-plan.sh`,
`scripts/codex-create-checklist.sh`, `prompts/`, `QUICK_START.md`,
`scripts/tests/audit-verdict-test.sh`, `MANUAL_CHECKLIST.md`, `FINAL_AUDIT.md`:
**empty**. `ADVERSARIAL_REVIEW.md` and `CHANGE_REQUEST.md` carry the same
uncommitted diffs they had before this stage began and were not touched.
A grep of the `change-workflow.sh` diff for `MODEL_*`, `EFFORT_*`, `BUDGET_*`,
`CODEX_EFFORT_*`, `AGENT_CMD`, `REVIEWER_CMD`, `CLAUDE_TOOLS`, the cost ledger,
the lock functions, and `verify_approval`: **no hits**.

## Security

- AR-001: a fresh run that merely finds a leftover `.workflow/origin` cannot
  close anything. Proven by `direct-run-stale-origin-fresh-state-skips-close`.
- AR-003: B-9's "a curl-fetched origin never authorizes a write" promise now
  applies to the driver-side path too, and a legacy two-field origin fails
  closed rather than gaining authority it never had.
- AR-004: a state/origin issue disagreement refuses with exit 1 and leaves the
  state file byte-identical (asserted).
- INV-3 is enforced by exactly one function, called by both entry points; there
  is no second, looser gate. CHANGE_SPEC §11 satisfied.
- INV-5 is untouched: `from-issue.sh` still refuses and never zeroes state. The
  only change is the added manual-clear guidance line.
- AR-008: the close runs under a 30s deadline (`timeout`/`gtimeout`); a timeout
  is a close failure — warning, no marker, exit 0, retryable later.

## Untested areas

- `scripts/stagegate.sh` — deliberately unmodified (AR-007/AR-009) and still
  uncovered by any automated suite, exactly as at baseline.
- Item A (opus vs. kimi) — no code, no test; not delivered.
- A real `gh` call against a real GitHub issue. All `gh` interaction is stubbed;
  MV-4, MV-5, MV-7, MV-8 cover it by hand.
- `verify_approval` / INV-4 — unchanged and, as at baseline, not exercised by
  either suite (BASELINE_REPORT.md §5, I-4, confidence Medium).
- The AR-008 no-`timeout`-available fallback path — this host has both binaries,
  so the degraded branch is reasoned about, not executed.
- Concurrency: the cross-driver race (AR-007) is not tested, being out of scope.

## Acceptance-criteria note

UPDATED_CHANGE_PLAN §"Exact acceptance criteria" item 2 predicts "149 checks".
The actual total is **207**. The arithmetic there adds *case* counts (~16 + 8)
to a *check* count (125); the suites count assertions, not cases. The substantive
bar — every pre-existing check green with no message-string edits, plus every new
case green — is met: 99/99 pre-existing close-flow checks still pass, all 24 new
cases pass (82 checks), and `audit-verdict-test.sh` is unchanged at 26/26.
