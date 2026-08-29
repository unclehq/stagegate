# Baseline Report

Omitted sections: none

## 1. Change-request summary

`CHANGE_REQUEST.md`: "Add help to each command. Place a README.md in scripts
that describes how to run each command." No change type, current/desired
behavior, constraints, or success criteria were filled in beyond that.
`GOOD_FIRST_ISSUES.md` Issue 9 (lines 222–244) is a pre-written spec matching
part of this request: `--help`/`--version` on `stagegate.sh` and
`change-workflow.sh` only, printing usage and exiting 0, with unknown args
printing usage and exiting non-zero. The change request's own wording ("each
command") is broader than Issue 9 and also covers the four other scripts and a
new `scripts/README.md`.

## 2. Repository architecture

Stagegate is a set of six standalone bash 3.2-compatible scripts (no shared
library file) plus markdown prompt templates, orchestrating two human-gated,
adversarially-reviewed pipelines for AI-generated code:

- `scripts/stagegate.sh` — new-application driver, reads `REQUIREMENTS.md`,
  resumable state machine keyed by `.workflow/state`.
- `scripts/change-workflow.sh` — change-request driver, reads
  `CHANGE_REQUEST.md`, same state-machine pattern plus a cost ledger.
- `scripts/from-issue.sh` — seeds `CHANGE_REQUEST.md`/`REQUIREMENTS.md` from a
  GitHub issue.
- `scripts/workflow.sh` — manual approval helper (`approve-plan`,
  `approve-review`, `approve-updated-plan`, `status`).
- `scripts/codex-review-plan.sh`, `scripts/codex-create-checklist.sh` —
  single-purpose Codex-invoking helpers, no arguments, called by the drivers
  or by hand.

Each script independently resolves `ROOT` from its own location
(`scripts/*.sh:4`, all six files) and `cd`s there, so they are relocatable as
a set but have no shared arg-parsing or usage-printing code to extend.

## 3. Relevant code paths

| File | Existing arg handling | Lines |
|---|---|---|
| `scripts/from-issue.sh` | `usage()` + `-h`/`--help` check already present | 7–29 |
| `scripts/workflow.sh` | `case "${1:-}"` with a `*)` fallback that prints usage and `exit 1` for anything unrecognized, including `-h`/`--help`/no args | 37–86 |
| `scripts/codex-review-plan.sh` | none — `$1` is never read | whole file (73 lines) |
| `scripts/codex-create-checklist.sh` | none — `$1` is never read | whole file (91 lines) |
| `scripts/stagegate.sh` | none — no top-level `$1`/`$#`/`$@` reference anywhere in the file | whole file (594 lines) |
| `scripts/change-workflow.sh` | none — no top-level `$1`/`$#`/`$@` reference anywhere in the file | whole file (675 lines) |

No `scripts/README.md` exists (`ls scripts/*.md` → no matches).

## 4. Current observable behavior

| ID | Trigger | Current result | Evidence | Must preserve? |
|---|---|---|---|---|
| B-01 | `./scripts/from-issue.sh --help` / `-h` / no args | Prints usage to stdout, exits 0 (no-args case) or 0 (explicit `-h`/`--help`); no-args also exits 0 per current code | ran: `./scripts/from-issue.sh --help`, `-h`, and no-args → identical usage text, `exit:0` all three | Yes |
| B-02 | `./scripts/workflow.sh` with no args, `-h`, or `--help` | Falls into the `*)` case, prints a `Usage:` block, exits 1 | ran all three → identical output, `exit:1` | Yes |
| B-03 | `./scripts/workflow.sh status` | Prints approval status table, exits 0 | ran → `PROJECT_PLAN.md: NOT APPROVED` etc., `exit:0` | Yes |
| B-04 | `./scripts/codex-review-plan.sh --help` | `--help` is silently ignored; script runs its precondition checks (`test -s PROJECT_PLAN.md`), which fail because `PROJECT_PLAN.md` does not exist in this repo, so it exits 1 with **no output at all** under `set -e` | ran → no stdout/stderr, `exit:1` | Behavior when preconditions are met must be preserved; the "no help text" behavior is exactly what the change request asks to fix |
| B-05 | `./scripts/codex-create-checklist.sh --help` | Same pattern: ignored, fails silently on `test -s UPDATED_PROJECT_PLAN.md`, `exit:1`, no output | ran → no stdout/stderr, `exit:1` | Same as B-04 |
| B-06 | `./scripts/stagegate.sh` / `--help` (no arg parsing exists) | Not executed in this baseline pass — see §11 | static read of full file, no `$1`/`$#`/`getopts`/`usage` match | Existing zero-arg invocation (documented in `README.md:93`) must keep working |
| B-07 | `./scripts/change-workflow.sh` / `--help` (no arg parsing exists) | Not executed in this baseline pass — see §11 | static read of full file, no `$1`/`$#`/`getopts`/`usage` match | Existing zero-arg invocation (`README.md:111`) must keep working |

## 5. Existing invariants

| ID | Invariant | Current enforcement | Existing test | Confidence |
|---|---|---|---|---|
| INV-01 | Every script starts with `set -euo pipefail`, so any unguarded non-zero command or unset-variable read aborts the script immediately with bash's own error, not a custom message | present verbatim at line 2 of all six scripts | none (no test suite in repo) | High |
| INV-02 | Every script resolves `ROOT` from its own path and `cd`s there before doing anything else, so it works regardless of caller's cwd | `scripts/*.sh:4-5`, all six | none | High |
| INV-03 | `workflow.sh`'s subcommand dispatch (`approve-plan`, `approve-review`, `approve-updated-plan`, `status`) is a `case "${1:-}"` — any value not matching those four falls through to usage+exit 1 | `scripts/workflow.sh:37-86` | none | High |
| INV-04 | `from-issue.sh` treats `-h`/`--help` and "no arguments" identically (usage, exit 0) but distinguishes them from an actual issue argument | `scripts/from-issue.sh:26-29` | none | High |
| INV-05 | `stagegate.sh` and `change-workflow.sh` read all configuration exclusively from environment variables (`WORKFLOW_*`), never from CLI flags | full-file grep, no `$1`/`getopts` outside function-local usages | none | High |
| INV-06 | Bash 3.2 compatibility is a hard constraint (macOS system bash) — no associative arrays, no `${var^^}`; `stagegate.sh` even has a comment and an `upper()` helper working around this (`stagegate.sh:44-47`) | comments at `stagegate.sh:44`, `README.md:78` | none | High |

## 6. Current API, schema, and interface contracts

CLI surface only (no library API). Documented entry points, per `README.md`:

- `./scripts/stagegate.sh` — zero arguments, all config via `WORKFLOW_*` env vars (README.md:204-242).
- `./scripts/change-workflow.sh` — zero arguments, `WORKFLOW_TRACK=small` env var for the small track (README.md:60-65).
- `./scripts/from-issue.sh <issue-number|url> [--change|--new]` (README.md:114-132).
- `./scripts/workflow.sh {approve-plan|approve-review|approve-updated-plan|status}` (README.md:280-284).
- `./scripts/codex-review-plan.sh`, `./scripts/codex-create-checklist.sh` — zero arguments, invoked by the drivers or by hand (README.md:280-284).

`README.md` itself is the closest thing to a "how to run each command"
document today; it describes usage in prose spread across multiple sections
rather than in a single `scripts/` reference, and it does not mention any
`--help` or `--version` flag on any script.

## 7. Existing automated-test coverage

None. No test directory, test framework, or CI config exists in the
repository (`find` for `*test*` and for `*.yml`/`*.yaml` outside `.git`
returned nothing).

## 8. Exact build and test commands executed

```sh
bash --version                                   # GNU bash 3.2.57(1) darwin
command -v shellcheck                            # not found
git log --oneline -20
git show --stat HEAD
ls -la scripts/ && wc -l scripts/*.sh
grep -n "usage()\|--help\|\"-h\"\|Usage:\|show_help\|print_help" -r scripts
grep -n 'usage\|--help\|"-h"\|^case\|getopts' scripts/change-workflow.sh
grep -n 'usage\|--help\|"-h"\|^case\|getopts' scripts/stagegate.sh
grep -n '\$1\|\$@\|\$#' scripts/change-workflow.sh scripts/stagegate.sh
ls PROJECT_PLAN.md UPDATED_PROJECT_PLAN.md AUTOMATED_TEST_REPORT.md \
   CHANGE_PLAN.md UPDATED_CHANGE_PLAN.md                # confirm absent, safe to probe codex-*.sh
./scripts/workflow.sh                 ; echo "exit:$?"
./scripts/workflow.sh --help          ; echo "exit:$?"
./scripts/workflow.sh -h              ; echo "exit:$?"
./scripts/workflow.sh status          ; echo "exit:$?"
./scripts/from-issue.sh --help        ; echo "exit:$?"
./scripts/from-issue.sh -h            ; echo "exit:$?"
./scripts/from-issue.sh               ; echo "exit:$?"
./scripts/codex-review-plan.sh --help      ; echo "exit:$?"
./scripts/codex-create-checklist.sh --help ; echo "exit:$?"
cat .workflow/state ; ls .workflow/logs ; ls .workflow/speculative
```

No formatter, compiler, type checker, or lint tool applies to this repository
(bash scripts, no `shellcheck` installed, no linter config present).

## 9. Baseline test results

There is no automated test suite to run, so "baseline test results" here means
the observed outputs of the commands in §8:

- `workflow.sh` (no args / `-h` / `--help`) → usage block, `exit 1` (all three
  byte-identical).
- `workflow.sh status` → three-line approval table, all `NOT APPROVED`,
  `exit 0`.
- `from-issue.sh` (no args / `-h` / `--help`) → identical usage text,
  `exit 0` for all three.
- `codex-review-plan.sh --help` → no output, `exit 1` (fails silently on
  missing `PROJECT_PLAN.md` before any `--help` handling would occur).
- `codex-create-checklist.sh --help` → no output, `exit 1` (fails silently on
  missing `UPDATED_PROJECT_PLAN.md`).
- `stagegate.sh` and `change-workflow.sh` were **not executed**, including
  with `--help` — see §11 for why.

## 10. Existing failures, warnings, and flaky behavior

None observed in the commands executed. No flakiness applicable — all
commands run were deterministic, argument-driven, read-only with respect to
tracked files.

## 11. Reproduction result for the reported bug, if applicable

Not a bug; this is a feature/documentation request. The absence of help text
is confirmed above (§4, §9) for four of six scripts by direct execution.

For `stagegate.sh` and `change-workflow.sh`, I did not execute the scripts
(with or without `--help`) as part of this baseline, including in this
repository, because:

- Static inspection (§3, INV-05) shows neither script reads `$1`/`$#`/`$@` at
  the top level, has any `getopts`/case dispatch on arguments, or checks for
  `--help`/`-h` anywhere in the file. Any invocation — bare or with any flag —
  falls straight through to the real state machine.
- This repository has pre-existing `.workflow/logs/baseline.jsonl` and
  `requirements.jsonl` from prior real runs of these drivers against this same
  repo (dogfooding), and no `.workflow/state` file, meaning a bare invocation
  would start a fresh run at the first state and immediately shell out to the
  `claude` and/or `codex` CLIs — a real, billed, side-effecting action, not a
  safe reproduction step.
- The absence of any argument handling is independently confirmed by
  exhaustive grep (§3), which is sufficient evidence for a baseline without
  incurring that cost.

## 12. Likely change surface

- All six files in `scripts/` gain some form of `-h`/`--help` handling (and,
  per `GOOD_FIRST_ISSUES.md` Issue 9, `--version` on the two main drivers).
- A new `scripts/README.md` documenting how to run each command.
- Possibly `README.md`'s "Manual helpers" / configuration sections gain a
  pointer to the new `scripts/README.md` (not required by the change request,
  but `CONTRIBUTING.md:79` establishes a convention of updating `README.md`
  alongside related docs).

## 13. Regression-sensitive components

- `workflow.sh`'s existing `case "${1:-}"` dispatch (INV-03) — adding
  `-h`/`--help` handling must not change the `exit 1` fallback behavior for
  genuinely unknown subcommands, nor change `status`'s output.
- `from-issue.sh`'s existing `usage()`/`-h`/`--help` handling (INV-04) — must
  not be duplicated or shadowed by a new global help mechanism.
- `codex-review-plan.sh` / `codex-create-checklist.sh` — both are invoked
  automatically by `change-workflow.sh`'s `run_codex` (no flags), so any new
  argument handling must not change zero-argument behavior.
- `stagegate.sh` / `change-workflow.sh` state machines — these are the highest
  blast-radius files in the repo (594 and 675 lines, drive real spend against
  `claude`/`codex`). Adding `--help`/`--version` must short-circuit before
  `mkdir -p`, before reading `WORKFLOW_*` env vars for anything other than
  possibly a version string, and before the `while true` state-machine loop —
  i.e., as the very first statements after `cd "$ROOT"`.
- Bash 3.2 compatibility (INV-06) — any new arg-parsing must avoid
  associative arrays, `${var^^}`, and lazy regex quantifiers (the existing
  `from-issue.sh` history at `5903a57` shows a bash-3.2 ERE regression that
  was already hit once).

## 14. Areas explicitly outside the change

`CHANGE_REQUEST.md`'s own "Out of Scope" section is unfilled. No file lists an
explicit exclusion. Treating as out of scope by default, absent a spec:
prompt files under `prompts/`, the state-machine logic itself, cost-ledger
format, and the approval/hash mechanism — none of these are "help text."

## 15. Unknowns and assumptions

- CHANGE_REQUEST.md does not specify exact `--help` wording, whether
  `--version` is in scope (only `GOOD_FIRST_ISSUES.md` Issue 9 mentions it),
  or where `scripts/README.md` should live relative to the existing
  `README.md` prose. Assumption: follow Issue 9's acceptance criteria for
  `stagegate.sh`/`change-workflow.sh` (help exits 0, unknown args exit
  non-zero) and extend the same pattern to the remaining four scripts for
  consistency, since the change request says "each command."
- Assumption: `codex-review-plan.sh` and `codex-create-checklist.sh` take no
  positional arguments today and won't gain any beyond `-h`/`--help` — adding
  full argument parsing to them is not implied by the change request.
- Assumption: a starting version string of `0.1.0` (per Issue 9) is
  acceptable if `--version` is implemented, since no version currently exists
  anywhere in the repo (no `VERSION` file, no version string in any script).

## 16. Initial risk assessment

Low technical risk: this is additive CLI surface (new flags, new doc file) on
scripts with no test suite and no consumers other than a human running them
directly or the drivers invoking the codex-* helpers with zero arguments. The
main risk is scope ambiguity (six scripts vs. two, per §1) and accidentally
changing exit-code/output behavior for existing flags/subcommands (`workflow.sh`
dispatch, `from-issue.sh` usage) while adding the new help path. No risk of
data loss or irreversible action from the change itself; the risk documented
in §11 is specific to *verifying* `stagegate.sh`/`change-workflow.sh`, not to
implementing the change.
