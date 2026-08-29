# Change Spec

Omitted sections: Performance requirements (no perf-sensitive path touched); Migration requirements (no data/schema/state format change); Prototype-isolation requirements (no prototype/experimental behavior introduced).

## 1. Change type

Feature (CLI help/usage surface + documentation).

## 2. Problem statement

None of the six `scripts/*.sh` commands has consistent `-h`/`--help` handling,
two (`codex-review-plan.sh`, `codex-create-checklist.sh`) fail silently with
no output on `--help`, and there is no single document describing how to run
each script. `CHANGE_REQUEST.md` asks for help on "each command" and a
`scripts/README.md`.

## 3. Current behavior

See BASELINE_REPORT.md §4 (B-01..B-07), §6.

## 4. Desired behavior

- All six scripts respond to `-h`/`--help`: print a short usage summary to
  stdout, exit 0.
- `stagegate.sh` and `change-workflow.sh` additionally respond to `--version`:
  print `0.1.0`, exit 0 (per `GOOD_FIRST_ISSUES.md` Issue 9).
- Any unrecognized flag/argument on any of the six scripts prints usage
  (to stderr) and exits non-zero, without side effects (no `mkdir -p`, no
  `claude`/`codex` invocation, no state-machine iteration).
- `--help`/`--version`/unknown-arg handling runs before any other
  side-effecting statement, immediately after `cd "$ROOT"`.
- New `scripts/README.md` lists all six scripts, one-line purpose, and exact
  invocation syntax for each.

## 5. Acceptance criteria

- AC-01: `./scripts/stagegate.sh --help` and `-h` → usage text on stdout, exit 0, no `.workflow/` mutation, no `claude`/`codex` call.
- AC-02: `./scripts/stagegate.sh --version` → prints `0.1.0`, exit 0.
- AC-03: `./scripts/change-workflow.sh --help`/`-h`/`--version` → same as AC-01/AC-02.
- AC-04: `./scripts/stagegate.sh --bogus` and `./scripts/change-workflow.sh --bogus` → usage on stderr, exit non-zero, no side effects.
- AC-05: `./scripts/codex-review-plan.sh --help` and `./scripts/codex-create-checklist.sh --help` → usage text, exit 0, no precondition-file check performed.
- AC-06: `./scripts/workflow.sh` no-args/`-h`/`--help` → usage, exit 0 (changed from current exit 1; see INV-03 below). `workflow.sh status` and the four `approve-*` subcommands are byte-identical to current behavior.
- AC-07: `./scripts/from-issue.sh --help`/`-h`/no-args → unchanged (usage, exit 0).
- AC-08: `scripts/README.md` exists and documents invocation syntax for all six scripts.
- AC-09: No existing zero-argument invocation of `stagegate.sh` or `change-workflow.sh` changes behavior (help/version/unknown-arg checks only trigger when `$1` is one of the recognized flags or an unrecognized one — absence of `$1` falls through to existing behavior unchanged).

## 6. Observable behavior table

| ID | Class | Trigger | Current behavior | Expected behavior | Verification |
|---|---|---|---|---|---|
| BH-01 | ADD | `stagegate.sh --help`/`-h` | Falls through to state machine (B-06) | Usage text, exit 0, no side effects | AC-01 |
| BH-02 | ADD | `stagegate.sh --version` | Falls through to state machine | Prints `0.1.0`, exit 0 | AC-02 |
| BH-03 | ADD | `stagegate.sh <unknown-flag>` | Falls through to state machine | Usage on stderr, exit non-zero | AC-04 |
| BH-04 | PRESERVE | `stagegate.sh` (no args) | Runs state machine (README.md:93) | Unchanged | AC-09 |
| BH-05 | ADD | `change-workflow.sh --help`/`-h` | Falls through to state machine (B-07) | Usage text, exit 0, no side effects | AC-03 |
| BH-06 | ADD | `change-workflow.sh --version` | Falls through to state machine | Prints `0.1.0`, exit 0 | AC-03 |
| BH-07 | ADD | `change-workflow.sh <unknown-flag>` | Falls through to state machine | Usage on stderr, exit non-zero | AC-04 |
| BH-08 | PRESERVE | `change-workflow.sh` (no args) | Runs state machine (README.md:111) | Unchanged | AC-09 |
| BH-09 | ADD | `codex-review-plan.sh --help` | No output, exit 1 (B-04) | Usage text, exit 0 | AC-05 |
| BH-10 | PRESERVE | `codex-review-plan.sh` (no args) | Runs precondition checks then Codex review | Unchanged | AC-05 |
| BH-11 | ADD | `codex-create-checklist.sh --help` | No output, exit 1 (B-05) | Usage text, exit 0 | AC-05 |
| BH-12 | PRESERVE | `codex-create-checklist.sh` (no args) | Runs precondition checks | Unchanged | AC-05 |
| BH-13 | MODIFY | `workflow.sh` no-args/`-h`/`--help` | Usage, exit 1 (B-02) | Usage, exit 0 | AC-06 |
| BH-14 | PRESERVE | `workflow.sh status` / `approve-plan` / `approve-review` / `approve-updated-plan` | Existing behavior (B-03) | Unchanged | AC-06 |
| BH-15 | PRESERVE | `workflow.sh <unknown-subcommand>` (not `-h`/`--help`/empty) | Usage, exit 1 | Unchanged (still exit 1) | AC-06 |
| BH-16 | PRESERVE | `from-issue.sh --help`/`-h`/no-args | Usage, exit 0 (B-01) | Unchanged | AC-07 |
| BH-17 | ADD | `scripts/README.md` | Does not exist | Documents invocation for all six scripts | AC-08 |

## 7. Invariant table

| ID | Status | Invariant | Scope | Enforcement point | Verification |
|---|---|---|---|---|---|
| IV-01 | EXISTING | `set -euo pipefail` at top of every script (INV-01) | All 6 scripts | Line 2 | Manual diff review |
| IV-02 | EXISTING | `ROOT` resolved and `cd`'d before other logic (INV-02) | All 6 scripts | Lines 4-5 | Manual diff review; help/version checks must run after this, not before |
| IV-03 | RELAXED | `workflow.sh` dispatch: any unrecognized `$1` (including empty/`-h`/`--help`) → usage + exit 1 (INV-03) | `workflow.sh` | Lines 37-86 | AC-06; relaxed only for the empty/`-h`/`--help` cases, which now exit 0; genuinely unknown subcommands still exit 1 |
| IV-04 | EXISTING | `from-issue.sh` treats `-h`/`--help`/no-args identically, exit 0 (INV-04) | `from-issue.sh` | Lines 26-29 | AC-07 |
| IV-05 | EXISTING | `stagegate.sh`/`change-workflow.sh` config exclusively via `WORKFLOW_*` env vars, never CLI flags (INV-05) | Both drivers | Full file | AC-09; new flags are `--help`/`--version`/unknown only, no new config flags |
| IV-06 | EXISTING | Bash 3.2 compatibility: no associative arrays, no `${var^^}`, no lazy regex (INV-06) | All 6 scripts | Full file | Manual review of new arg-parsing code |
| IV-07 | NEW | Help/version/unknown-arg handling on `stagegate.sh`/`change-workflow.sh` executes before `mkdir -p`, before reading `WORKFLOW_*` vars (except a version string), and before the state-machine loop | Both drivers | Immediately after `cd "$ROOT"` | AC-01, AC-02, AC-03, AC-04 (no side effects) |
| IV-08 | NEW | `codex-review-plan.sh`/`codex-create-checklist.sh` `--help` handling executes before their precondition file checks (`test -s ...`) | Both codex-* scripts | Top of file, before precondition block | AC-05 |

**IV-03 is RELAXED** (workflow.sh no-args/`-h`/`--help` moves from exit 1 to exit 0) — flagged per Core rule 6; requires explicit human approval. Rationale: aligns `workflow.sh` with the other five scripts' convention (help exits 0); the "unknown subcommand" exit-1 behavior itself is unchanged and unaffected.

## 8. Compatibility requirements

- No script's zero-argument / documented-argument behavior changes (BH-04, BH-08, BH-10, BH-12, BH-14, BH-16).
- `workflow.sh <unknown-subcommand>` (anything other than empty/`-h`/`--help`) keeps exit 1 (BH-15).
- No new required environment variables or config files.

## 9. Error and failure behavior

- Unknown flags on `stagegate.sh`/`change-workflow.sh` → usage to stderr, non-zero exit, no filesystem/network/subprocess side effects.
- `--help`/`--version` never triggers precondition checks, `mkdir -p`, or external CLI invocation on any of the six scripts.

## 10. Security requirements

None beyond existing script trust boundary; no new external input parsed beyond flag literals already covered by `set -euo pipefail`.

## 11. Rollback expectations

Purely additive/localized diffs per script plus one new doc file; revertible via `git revert` of the change commit(s) with no data migration.

## 12. Explicit non-goals

- No argument parsing beyond `-h`/`--help`/`--version`/unknown-flag detection (no new configuration flags, per IV-05).
- No changes to state-machine logic, cost-ledger format, approval/hash mechanism, or `prompts/`.
- No test framework introduced (repo has none; out of scope per BASELINE_REPORT.md §7).
- `codex-review-plan.sh`/`codex-create-checklist.sh` gain only `--help`, not full flag parsing (per BASELINE_REPORT.md §15 assumption).

## 13. Assumptions and unresolved questions

- Exact usage-text wording is left to implementation; must name the script and its accepted arguments.
- `--version` scope limited to `stagegate.sh`/`change-workflow.sh` per Issue 9; not added to the other four scripts (change request's "each command" is read as "each command gets *help*", not "each command gets a version flag").
- Starting version string `0.1.0`, no `VERSION` file, per BASELINE_REPORT.md §15 — UNRESOLVED if the user wants a shared version source instead of a literal in each driver; defaulting to a literal for minimal change surface.
- `workflow.sh`'s IV-03 relaxation (exit 1 → exit 0 for no-args/`-h`/`--help`) requires explicit approval before implementation.
