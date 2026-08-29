# Change Test Report

Every line below was executed in this working tree unless it says `N/A` or
`NOT RUN`. `N/A` = the check does not apply to this repository or this change.
`NOT RUN` = it applies and was not executed.

## Baseline

- `for f in scripts/*.sh; do bash -n "$f"; done` — exit 0 for all 6 scripts, matching BASELINE §9.
- Argument-contract replay (BASELINE §8 lines 3-7, extended to all six scripts) — 13 invocations, all outputs and exit codes identical to BASELINE §9: `from-issue.sh` no-args/`--help` exit 0, `abc` exit 1; `change-workflow.sh` `--help` exit 0, `--version` `0.1.0`, `bogus` exit 1; `stagegate.sh` same shape; `workflow.sh` no-args exit 1, `--help` exit 0; both codex scripts `--help` exit 0.
- `git status --porcelain` before editing — 6 pre-existing modified artifacts recorded in IMPLEMENTATION_NOTES.md; none written to.

## Targeted tests

- `./scripts/tests/audit-verdict-test.sh` — exit 0, 26 checks passed (three documented verdicts, markdown/emphasis stripping, CRLF, trailing blanks, embedded-phrase and concatenated-phrase rejection, case sensitivity, empty/absent file).
- `./scripts/tests/close-flow-test.sh` — exit 0, 99 checks passed. Covers every row of UPDATED_CHANGE_PLAN §12: decline (wrong word / bare ENTER / EOF), piped-stdin prompt visible and blocking, READY and READY_WITH_NON_BLOCKING_ISSUES close, NOT_READY and UNKNOWN no-close, missing and malformed verdict file, run-id mismatch, origin mismatch, audit-hash mismatch, driver exits 1/7/130 propagated with no close, `USED_GH=0` skip, `gh` unauthenticated skip, `gh` absent skip, `gh issue close` failure → exit 1, seed gate (foreign origin, unowned state, same-origin resume, COMPLETE reseed, fresh checkout), lock held by a live PID, stale lock cleared and released on exit, preflight origin mismatch/absent/COMPLETE-passes, preflight skipped for standalone runs, stale audit rejected, verdict record contents.
- `./scripts/change-workflow.sh --help`, `--version`, `bogus` after each driver edit — unchanged (exit 0/0/1), and no `.workflow` file created by those paths.

## Regression tests

- `--new` byte-diff (AC-6/B-08): pre-change `from-issue.sh` (from `git show HEAD:`) and the changed one, each run in a scratch checkout against `https://github.com/unclehq/stagegate/issues/2 --new` — stdout, exit code, and resulting `REQUIREMENTS.md` all identical.
- End-to-end `--change` decline in a scratch checkout with a poisoned driver stub (`exit 9`): `CHANGE_REQUEST.md` written, prompt shown, decline honored, driver never invoked, exit 0, no `.workflow/` directory created — so a decline leaves no origin claim.
- Driver standalone guard (§17): `preflight-standalone-unaffected` in `close-flow-test.sh` — with a foreign `.workflow/origin` and in-flight state but no `STAGEGATE_ORIGIN_*`, the preflight does not fire.
- `.workflow/state` in this repository still reads `IMPLEMENT`; `.workflow/` contents unchanged from the pre-implementation listing.

## Full test suite

- `for f in scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh; do bash -n "$f"; done` — exit 0 for all 9 files (AC-7).
- `./scripts/tests/audit-verdict-test.sh && ./scripts/tests/close-flow-test.sh` — exit 0; 125 assertions total. These two scripts are the repository's entire automated suite (BASELINE §7: none existed before).

## Formatting

- N/A (no formatter configured for shell in this repository; BASELINE §2).

## Compiler or type checker

- N/A (bash; `bash -n` is the equivalent and is reported above).

## Linting

- `command -v shellcheck` — not installed; N/A (pre-existing, BASELINE §7/§10; shellcheck is not a repository dependency).

## Integration tests

- `./scripts/tests/close-flow-test.sh` doubles as the integration check: it runs the real `change-workflow.sh` and the real `from-issue.sh` functions against a scratch checkout with stubbed `gh` and stubbed reviewer. No live agent pipeline was run.

## Frontend build

- N/A (no frontend).

## Migration tests

- N/A (no persisted format migrates; `.workflow/origin`, `.workflow/lock/`, and the widened `.workflow/audit-verdict` are new files treated as absent-if-missing — asserted by `missing-verdict-file`, `seed-gate-fresh-checkout`, and `preflight-origin-absent`).

## Rollback test

- `git show HEAD:scripts/from-issue.sh` was extracted and executed in a scratch checkout as part of the `--new` byte-diff above: the pre-change script runs unmodified against this tree, so `git revert` restores working behavior. Deleting `scripts/lib/`, `scripts/tests/`, and the new `.workflow` files is inert — nothing else reads them (UPDATED_CHANGE_PLAN §14). Already-closed GitHub issues are not reopened by a rollback; unchanged from the plan.

## Performance checks

- N/A (no perf-sensitive path touched; CHANGE_SPEC §3 omits performance requirements). The added work per run is one `mkdir`, one `sha256`, and three small file reads.

## Security checks

- `gh issue close` appears exactly once in the repository (`scripts/from-issue.sh`), reached only after eight independent conditions hold; verified by reading the file and by the twelve negative-path cases in `close-flow-test.sh` that assert *no* `gh issue close` call reaches the stub.
- No new credential is stored; the existing `gh` session is reused, and `gh auth status` is re-checked at close time.
- `git check-ignore -v .workflow/origin .workflow/audit-verdict .workflow/lock/pid` — all ignored via `.gitignore:1`; no new state can be committed accidentally.

## Newly introduced warnings

- None observed in any of the runs above.

## Pre-existing failures

- None. `shellcheck` absence is pre-existing (BASELINE §10) and unchanged.

## Untested areas

- A real `gh issue close` against a live issue (M-04) and a real `NOT READY` audit leaving an issue open (M-05): both need a full agent-pipeline run and an irreversible GitHub write, so they are covered only by the stubbed decision path. They remain manual checks.
- M-07 with the real `gh` binary logged out (the automated case stubs `gh auth status` and strips `gh` from `PATH` instead).
- M-10 is covered, not untested: all six scripts were run from `/tmp` by absolute path (`--help`, exit 0, correct usage for each), and `close-flow-test.sh` invokes the driver by absolute path with a CWD outside its `ROOT`, exercising the self-relative `source` of `scripts/lib/audit-verdict.sh` through the `FINAL_AUDIT` classifier call.
- Cross-clone concurrent runs against one issue — out of scope by UPDATED_CHANGE_PLAN §22, not tested.
- Stale-lock PID reuse — cannot be provoked deterministically; safe direction only (false refusal, never false proceed).
