# Change Test Report

Repository has no test framework, formatter, compiler, linter, or CI
(BASELINE_REPORT §7, §8). Checks below are the T-01..T-14 suite from
UPDATED_CHANGE_PLAN §12 plus the standard categories, each marked run, `N/A`,
or `NOT RUN`.

Test-harness note: the tool shell is zsh, which does not word-split unquoted
`$var` and applies MULTIOS to `2>&1 >/dev/null`. Two early harness passes
produced spurious results from this; every assertion below was re-executed
from a `#!/usr/bin/env bash` script file (`/tmp/sg-final.sh`,
`/tmp/sg-drv.sh`). Only the bash-executed results are reported.

## Baseline

| Check | Result |
|---|---|
| `shasum -a 256 UPDATED_CHANGE_PLAN.md CHANGE_SPEC.md BASELINE_REPORT.md` vs `.workflow/approvals/*.sha256` | PASS — all three match their approval records |
| `git status --porcelain` (pre-change) | PASS — only untracked workflow artifacts; no tracked modifications, no unrelated work at risk |
| Golden-fixture capture (AR-009, §7.2): stdout/stderr/exit for `workflow.sh status`, `workflow.sh bogus-subcommand`, `workflow.sh` no-args, `-h`, `--help`, `from-issue.sh --help`/`-h`/no-args, `codex-*.sh` no-args → `/tmp/sg-golden/` | PASS — 10 fixtures captured pre-edit; baseline exits reproduce BASELINE_REPORT §9 exactly (`wf-*`=1, `wf-status`=0, `fi-*`=0, `codex-*`=1 with 0-byte output) |
| §7.4 re-grep for in-repo callers passing arguments | PASS — none; only documentation strings |

## Targeted tests

Run against the working tree; none of these paths can spawn an agent.

| Check | Result |
|---|---|
| T-05 `codex-review-plan.sh --help`/`-h`, `codex-create-checklist.sh --help`/`-h` | PASS — exit 0, non-empty stdout, empty stderr, each output contains its own basename and not the other's (AR-008) |
| T-06 `codex-review-plan.sh --bogus`, `codex-create-checklist.sh --bogus`, plus `--help extra` on both | PASS — exit 1, non-empty stderr, empty stdout on all four |
| T-07 `workflow.sh -h`, `--help` | PASS — exit 0, usage on stdout byte-identical to baseline text, empty stderr |
| T-07 (AR-001 clause) `.workflow/approvals` not created by `workflow.sh -h`/`--help` | PASS — verified in the clean worktree fixture; see Integration below |
| T-11 `for f in scripts/*.sh; do bash -n "$f"; done` | PASS — all 6 files parsed individually, exit 0 (AR-004 form) |
| T-12 `test -s scripts/README.md`; all six scripts named with an invocation line; every `*.md` / `--flag` token in each script's `usage()` present in the README; `--version` accepted by exactly the two drivers | PASS — 0 mismatches |
| Exit-code matrix, 17 in-tree cases (help/version/unknown/trailing/subcommand across `workflow.sh`, both `codex-*`, `from-issue.sh`) | PASS — 17/17 |

## Regression tests

| Check | Result |
|---|---|
| T-08 `workflow.sh status` vs golden fixture (`cmp` on stdout, stderr, exit) | PASS — byte-identical |
| T-09 `workflow.sh bogus-subcommand` vs golden fixture | PASS — byte-identical (stdout, exit 1) |
| T-09b `workflow.sh` no-args vs golden fixture | PASS — byte-identical (stdout, exit 1); see IMPLEMENTATION_NOTES D-1, this is the deliberately-unchanged narrow branch |
| T-10 `from-issue.sh --help`/`-h`/no-args vs golden fixtures | PASS — all three byte-identical |
| T-14 (AR-006) zero-argument `stagegate.sh`, `change-workflow.sh`, `codex-review-plan.sh`, `codex-create-checklist.sh`, each run on a pre-change worktree and a post-change worktree with `WORKFLOW_*_CMD=false`, paths normalized | PASS — stdout, stderr, and exit status identical pre/post for all four (`stagegate.sh` exit 1/237B, `change-workflow.sh` exit 1/177B, both `codex-*` exit 1/0B) |

## Full test suite

`N/A (no test framework, test directory, or CI config exists in this repository — BASELINE_REPORT §7)`. The T-01..T-14 suite above is the complete applicable check set.

## Formatting

`N/A (no formatter applies; repository is bash scripts and markdown, no formatter configured — BASELINE_REPORT §8)`

## Compiler / type checker

`bash -n` on all six scripts — PASS (see T-11). No other compiler or type checker applies.

## Linting

`N/A (shellcheck not installed — "command -v shellcheck" not found per BASELINE_REPORT §8; no linter config in repo)`

## Integration tests

Run under the §11 containment: `git worktree add --detach` clean checkouts (no
gitignored `.workflow/` carried over — AR-007), `WORKFLOW_AGENT_CMD=false
WORKFLOW_REVIEWER_CMD=false`, `test ! -e .workflow` asserted before and after
every invocation.

| Check | Result |
|---|---|
| Fixture cleanliness before use (`test ! -e .workflow` on both worktrees) | PASS — absent in both; post-worktree differs from pre only in the 5 modified scripts |
| T-01 `stagegate.sh --help`, `-h` | PASS — exit 0, non-empty stdout, empty stderr, output names `stagegate.sh` |
| T-02 `stagegate.sh --version` | PASS — stdout exactly `0.1.0`, exit 0 |
| T-03 `change-workflow.sh --help`, `-h`, `--version` | PASS — as T-01/T-02, output names `change-workflow.sh` |
| T-04 `stagegate.sh --bogus`, `stagegate.sh --help extra`, `change-workflow.sh --bogus`, `change-workflow.sh --version extra` | PASS — exit 1, usage on stderr, empty stdout on all four (AR-005 trailing-arg forms included) |
| `.workflow` creation check after each of the 12 containment invocations (incl. `workflow.sh -h`/`--help`) | PASS — never created on any help/version/unknown path |
| T-13 `git status --porcelain` before/after the containment run | PASS — no tracked-file change |
| Fixture teardown `git worktree remove --force` (R-7) | PASS — both removed; `git worktree list` shows only the main tree |

## Migration tests

`N/A (no data, schema, or state-format change — CHANGE_SPEC omits migration requirements; state file, approval hashes, and cost-ledger formats untouched)`

## Rollback test

`NOT RUN (rollback is "git revert the change commit" per CHANGE_SPEC §11; no commit has been created yet, so there is nothing to revert. The change is confined to 6 tracked files plus 1 new file, is purely additive apart from the workflow.sh case re-key, and touches no persisted state.)`

## Performance checks

`N/A (no performance-sensitive path touched — CHANGE_SPEC omits performance requirements; the added code is one case statement executed once per invocation)`

## Security checks

`N/A beyond the existing trust boundary (CHANGE_SPEC §10). No new external input is parsed: the guards compare "$#:${1:-}" against literal patterns and never evaluate, expand, or pass argument content to a subprocess. "$1" is interpolated only into a printf format argument, not the format string.`

## Frontend build

`N/A (no frontend in this repository)`

## Newly introduced warnings

None. `bash -n` is clean on all six scripts; no runtime warning appeared in any of the 40+ invocations above.

## Pre-existing failures

- `codex-review-plan.sh` and `codex-create-checklist.sh` with zero arguments exit 1 with no output, because their precondition files (`PROJECT_PLAN.md`, `UPDATED_PROJECT_PLAN.md`, `AUTOMATED_TEST_REPORT.md`) do not exist in this repository. Pre-existing (BASELINE_REPORT B-04/B-05); confirmed unchanged pre/post by T-14.
- `stagegate.sh` and `change-workflow.sh` with zero arguments exit 1 in a clean checkout. Pre-existing and outside this change's scope; confirmed byte-identical pre/post by T-14.

## Untested areas

- The two drivers' state machines beyond argument handling. Never executed with a real agent, before or after this change (BASELINE_REPORT §11 declined for cost reasons; §11 containment stubs the CLI with `false`). The change inserts code strictly before `STATE_DIR=`, and T-14 shows the zero-argument entry path is byte-identical.
- `codex-*.sh` behavior when preconditions are satisfied — cannot be exercised without an approved `PROJECT_PLAN.md` and a real reviewer CLI. Guard placement is above the precondition block, verified by MC-01.
- `from-issue.sh` with a real issue argument (requires `gh` auth / network). Unmodified file; only its preserved help forms were checked (T-10).
- `workflow.sh approve-*` subcommands — interactive (`read -p` requires typing `APPROVE`) and they write approval records. Not executed to avoid mutating this repository's live approval state. Their dispatch arms were changed only by the `1:` prefix on the case pattern; `1:status` exercises the identical dispatch mechanism and is byte-identical (T-08).

## Manual checks (§14)

| ID | Result |
|---|---|
| MC-01 | PASS — `workflow.sh:18` case precedes `mkdir -p` at `:22`; `stagegate.sh:22` and `change-workflow.sh:23` precede `STATE_DIR=` at `:29`/`:30` and `mkdir -p` at `:35`/`:37`; `codex-review-plan.sh:20` and `codex-create-checklist.sh:22` precede the `test -s` blocks at `:26`/`:28` |
| MC-02 | PASS — lines 1–5 byte-identical to the expected header in all six scripts; `set -euo pipefail` intact |
| MC-03 | PASS — diff contains no `declare -A`, no `${var^^}`, no `=~`; confirmed executable by T-11 under bash 3.2-compatible syntax |
| MC-04 | PASS — no new `WORKFLOW_*` *read* added; the four diff hits are prose inside `usage()` heredocs, with no `$` expansion |
| MC-05 | PASS — cross-read of `scripts/README.md` against each script's actual arguments and `usage()` text; no documented flag that does not exist, no flag left undocumented, no cross-script copy-paste. One correction applied during this check (IMPLEMENTATION_NOTES D-2) |
| MC-06 | PASS — worktree containment used for T-01..T-04 and T-14; `WORKFLOW_AGENT_CMD`/`WORKFLOW_REVIEWER_CMD` stubbed to `false` throughout; no `claude`/`codex` process spawned and no cost-ledger file created (`.workflow` verified absent after every invocation) |
| MC-07 | PASS — all five guarded scripts key on `case "$#:${1:-}"` (`workflow.sh` has two such cases: the early exit and the re-keyed dispatch) |
| MC-08 | PASS — `workflow.sh` unknown input → 160B stdout, 0B stderr, exit 1; `from-issue.sh --bogus-flag` → 639B stdout, 0B stderr, exit 1; both documented in `scripts/README.md` as an intentional exception |

## Acceptance criteria

| AC | Status |
|---|---|
| AC-01 | PASS (T-01, T-04) |
| AC-02 | PASS (T-02) |
| AC-03 | PASS (T-03, T-04) |
| AC-04 | PASS (T-04) |
| AC-05 | PASS (T-05, T-06, T-14) |
| AC-06 | **PARTIAL** — `-h`/`--help` → exit 0 (T-07); `status`/`approve-*` byte-identical (T-08). The no-argument case still exits 1: IV-03 relaxation not approved explicitly, narrow branch taken per §7.1/§10 (IMPLEMENTATION_NOTES D-1) |
| AC-07 | PASS (T-10) |
| AC-08 | PASS (T-12, MC-05) |
| AC-09 | PASS (T-13, T-14) |

## Stopping conditions (§10)

| Condition | Triggered? |
|---|---|
| Approval does not explicitly address the IV-03 relaxation | **YES** — narrow `workflow.sh` change implemented per §7.1; recorded as D-1. Did not proceed to exit-0-for-bare-no-args. |
| Golden-fixture diff mismatch | No — all 6 preserved forms byte-identical |
| Contaminated worktree fixture (`.workflow` present) | No — absent in both fixtures before use |
| `claude`/`codex` process spawned, or cost ledger grew | No |
| MC-01 finds a guard after a side-effecting statement | No |
