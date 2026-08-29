# Change Plan

Omitted sections: State-transition changes (no `.workflow/state` value, transition, or ordering is touched; the new guards exit before the state machine is entered); Schema or persistence changes (no file format, ledger, or approval-hash change); Concurrency implications (help/version exits before `WORKFLOW_SPECULATE` background stages are spawned — IV-07 — and no concurrent path is modified); Migration plan (no persisted data or state format changes; nothing to migrate).

## 1. Selected technical approach

Per-script inline argument guard. In each of the five scripts that change, add a
`usage()` heredoc function plus a `case "${1:-}"` guard placed immediately after
`cd "$ROOT"` (line 5) and before the first side-effecting statement. No shared
library, no sourcing, no `getopts`.

Guard shape for `stagegate.sh` / `change-workflow.sh` (inserted at line 6, above
`STATE_DIR=` and `mkdir -p`):

```sh
STAGEGATE_VERSION="0.1.0"

usage() {
    cat <<'EOF'
Usage: stagegate.sh [-h|--help] [--version]

Run the human-gated new-application workflow from REQUIREMENTS.md.
Takes no positional arguments; all configuration is via WORKFLOW_* environment
variables (see scripts/README.md).
EOF
}

case "${1:-}" in
    -h|--help)  usage; exit 0 ;;
    --version)  printf '%s\n' "$STAGEGATE_VERSION"; exit 0 ;;
    "")         ;;
    *)          printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 1 ;;
esac
```

Guard shape for `codex-review-plan.sh` / `codex-create-checklist.sh` (inserted at
line 6, above the `test -s ...` precondition block): same, minus the
`--version` branch.

`workflow.sh`: extract the existing `*)` heredoc into a `usage()` function
defined above the `case`, then add one branch `-h|--help|"") usage; exit 0 ;;`
ahead of the existing `*)` branch. The `*)` branch keeps its current text,
current stdout stream, and `exit 1`.

`from-issue.sh`: no source change (BH-16 PRESERVE).

New file `scripts/README.md`: one section per script — purpose, exact invocation
syntax, arguments, relevant `WORKFLOW_*` variables, exit codes.

Conventions fixed here so the six scripts agree:

| Decision | Value | Reason |
|---|---|---|
| Help stream / exit | stdout, `exit 0` | Spec §4; matches `from-issue.sh` (IV-04) |
| Unknown-arg stream | stderr | Spec §4 — except `workflow.sh`'s existing `*)` branch, kept on stdout to satisfy BH-15 "unchanged" (see §22 Q-1) |
| Unknown-arg exit code | `1` | Repo already uses 1 for this (`from-issue.sh:39`, `workflow.sh:84`); BH-15 requires 1 |
| Version string | literal `STAGEGATE_VERSION="0.1.0"` in each of the two drivers | Spec §13 default; no `VERSION` file (see §22 Q-2) |
| Guard inspects | `$1` only | Both drivers accept zero positional arguments; anything in `$1` is either a known flag or unknown |

## 2. Alternative approaches considered

| # | Approach | Outcome |
|---|---|---|
| A-1 | Shared `scripts/_common.sh` with `parse_common_args()`, sourced by all six | Rejected |
| A-2 | Per-script inline guard (selected) | Selected |
| A-3 | `getopts` / full option loop per script | Rejected |
| A-4 | Issue 9 scope only: `--help`/`--version` on the two drivers, no other script, no `scripts/README.md` | Rejected |
| A-5 | Guard placed before `cd "$ROOT"` (line 4) so help works even if `ROOT` resolution fails | Rejected |

## 3. Why the selected approach is preferred

- A-1 breaks INV-02/IV-02's property that each script is independently
  self-resolving: sourcing adds an ordering dependency and a new failure mode
  (missing/renamed `_common.sh` aborts every script under `set -e`). Usage text
  is per-script anyway, so the shared file would save roughly four lines each
  while adding a seventh file and a cross-file coupling the repo does not have
  today.
- A-3 is more machinery than the spec permits: §12 forbids argument parsing
  beyond `-h`/`--help`/`--version`/unknown detection, and `getopts` does not
  handle long options in bash 3.2 (IV-06) without a hand-written loop anyway.
- A-4 contradicts CHANGE_SPEC §4 and AC-05/AC-06/AC-08.
- A-5 would place logic before the `cd`, violating IV-02's "resolve and `cd`
  before other logic" ordering; the guard runs immediately after instead.
- A-2 keeps the diff local (one contiguous block per file), leaves the state
  machines untouched, and is trivially revertible per file.

## 4. Exact components to modify

| File | Insertion point | Change |
|---|---|---|
| `scripts/stagegate.sh` | new lines after `cd "$ROOT"` (line 5), before `STATE_DIR=` (line 7) | version literal, `usage()`, `case` guard with `--version` |
| `scripts/change-workflow.sh` | new lines after `cd "$ROOT"` (line 5), before `STATE_DIR=` (line 7) | version literal, `usage()`, `case` guard with `--version` |
| `scripts/codex-review-plan.sh` | new lines after `cd "$ROOT"` (line 5), before `test -s REQUIREMENTS.md` (line 7) | `usage()`, `case` guard, no `--version` |
| `scripts/codex-create-checklist.sh` | new lines after `cd "$ROOT"` (line 5), before `test -s REQUIREMENTS.md` (line 7) | `usage()`, `case` guard, no `--version` |
| `scripts/workflow.sh` | `usage()` defined after `approve_file` (line 35); new `case` branch before `*)` (line 75) | `-h`/`--help`/empty → usage, exit 0; `*)` body unchanged except calling `usage` |
| `scripts/README.md` | new file | Invocation reference for all six scripts |
| `README.md` (OPTIONAL, OPT-01) | "Manual helpers" section | One-line pointer to `scripts/README.md` |

Verified before planning: no `usage` function or `VERSION` identifier exists in
any script except `from-issue.sh:7`, so no name collision is introduced.

## 5. Components explicitly not to modify

| Component | Reason |
|---|---|
| `scripts/from-issue.sh` | BH-16 PRESERVE; already conforms (IV-04). Do not fold it into a shared mechanism. |
| State machines in both drivers (`while` loop, stage table, gates) | Spec §12 non-goal |
| `run_codex` / `run_agent` and the cost ledger in `change-workflow.sh` | Spec §12 non-goal |
| `mkdir -p .workflow/approvals` at `workflow.sh:7` | Left in place; `workflow.sh --help` creates that directory today and will continue to. Moving it would be an unrequested behavior change. |
| Approval/hash mechanism, `prompts/`, `GOOD_FIRST_ISSUES.md` | Spec §12 non-goal |
| `set -euo pipefail` and `ROOT`/`cd` prologue (lines 1–5) of every script | IV-01, IV-02 |
| `workflow.sh` `*)` usage text and stdout stream | BH-15 |

## 6. Data-flow changes

One new early-exit path per modified script: `argv[1] → case → (usage → stdout →
exit 0) | (version → stdout → exit 0) | (unknown → stderr → exit 1) | (empty →
fall through to existing flow)`. No existing data flow is rerouted; the empty
case reaches the original first statement with identical state.

Newly reachable-before: nothing. Newly unreachable on the help/version/unknown
paths: `mkdir -p` (both drivers), `WORKFLOW_*` reads, `test -s` preconditions
(both `codex-*` scripts), all `claude`/`codex` invocation, the state-machine
loop.

## 7. Interface and API changes

| Script | Before | After |
|---|---|---|
| `stagegate.sh` | zero args, any argv silently ignored → state machine | `-h`/`--help`/`--version` handled; unknown argv rejected; zero args unchanged |
| `change-workflow.sh` | same | same |
| `codex-review-plan.sh` | zero args, argv ignored | `-h`/`--help` handled; unknown argv rejected; zero args unchanged |
| `codex-create-checklist.sh` | same | same |
| `workflow.sh` | 4 subcommands; everything else → usage + exit 1 | adds empty/`-h`/`--help` → usage + exit 0; 4 subcommands and unknown-subcommand path unchanged |
| `from-issue.sh` | unchanged | unchanged |

No library API, no env-var additions (IV-05 holds: the new flags carry no
configuration).

## 8. Compatibility strategy

- The `""` branch in every `case` guarantees zero-argument behavior is
  byte-identical (AC-09, BH-04/08/10/12).
- No in-repo caller passes arguments to any script: `change-workflow.sh` uses
  its own inline `run_codex` (line 370) rather than the `codex-*` helpers, and
  no script invokes another. The only callers are humans and the agent following
  `CLAUDE.md` Stage 2/6, both zero-argument. (Note: BASELINE_REPORT §13 states
  the `codex-*` helpers are invoked by `run_codex`; grep of `scripts/` shows no
  such invocation. Regression risk there is therefore lower than the baseline
  assumed, not higher.)
- `workflow.sh` unknown subcommand keeps exit 1 (BH-15); only empty/`-h`/`--help`
  move to exit 0 (IV-03 RELAXED, approved at the CHANGE_SPEC gate).
- Bash 3.2 (IV-06): `case`, `printf`, quoted heredocs only; no associative
  arrays, no `${var^^}`, no regex.

## 9. Error and recovery behavior

| Condition | Behavior |
|---|---|
| Unknown flag/arg on the 4 newly-guarded scripts | `Unknown argument: <arg>` + usage to stderr, exit 1, no filesystem/network/subprocess effect |
| Unknown subcommand on `workflow.sh` | unchanged: usage to stdout, exit 1 |
| `-h`/`--help`/`--version` | usage or version to stdout, exit 0, no side effect (IV-07, IV-08) |
| Trailing arguments after a recognized flag (`--help extra`) | `$1` matches, help printed, exit 0; extra args ignored. Accepted — the drivers take no positionals, so this is unreachable in documented use. |
| Nothing to recover | The guards perform no writes, so no partial state is possible on any new path |

## 10. Rollback plan

- Each script's guard is one contiguous inserted block plus (for `workflow.sh`)
  one added `case` branch. `git checkout HEAD -- scripts/<file>` restores any
  single script independently; the scripts have no cross-dependency, so a
  partial rollback leaves a working system with mixed help coverage.
- Full rollback: `git revert <commit>` — additive diffs plus one new untracked-
  then-tracked file, no data migration, no state to unwind (`.workflow/` is
  untouched by this change).
- Detection signal for needing rollback: any zero-argument invocation of
  `stagegate.sh`, `change-workflow.sh`, `workflow.sh <subcommand>`, or the
  `codex-*` helpers failing where it previously succeeded.

## 11. Feature-flag and containment strategy

No feature flag: the change is a guard on an argument surface that is currently
unused, and a flag would add configuration the spec forbids (§12, IV-05).

Containment applies to **verification**, which is the risky part. BASELINE_REPORT
§11 declined to execute the two drivers because a fall-through starts a real,
billed run. Verification of AC-01..AC-04 must therefore run under all three of:

1. A throwaway copy of the repo (`cp -R` to a temp dir, or `git worktree add`);
   each script resolves `ROOT` from its own path (IV-02), so a copy is fully
   isolated from this working tree.
2. `WORKFLOW_AGENT_CMD=false WORKFLOW_REVIEWER_CMD=false` exported, so any
   fall-through cannot invoke `claude` or `codex` and dies immediately under
   `set -e` with no spend.
3. The copy has no `.workflow/` directory, so `mkdir -p` becoming reachable is
   directly observable as a created directory.

## 12. Automated-test strategy

The repository has no test runner and CHANGE_SPEC §12 rules out introducing one.
Automated verification is therefore a fixed command matrix, executed under the
§11 containment and recorded verbatim (command, stdout/stderr, exit code) in
`CHANGE_TEST_REPORT.md`. Never mark an unexecuted command as passed.

| ID | Command | Expected |
|---|---|---|
| T-01 | `stagegate.sh --help`; `-h` | usage on stdout, exit 0, no `.workflow/` created |
| T-02 | `stagegate.sh --version` | `0.1.0`, exit 0 |
| T-03 | `change-workflow.sh --help`; `-h`; `--version` | as T-01/T-02 |
| T-04 | `stagegate.sh --bogus`; `change-workflow.sh --bogus` | usage on stderr, exit 1, no `.workflow/` created |
| T-05 | `codex-review-plan.sh --help`; `-h`; and same for `codex-create-checklist.sh` | usage on stdout, exit 0, no precondition failure |
| T-06 | `codex-review-plan.sh --bogus` | usage on stderr, exit 1 |
| T-07 | `workflow.sh`; `-h`; `--help` | usage on stdout, exit 0 (was exit 1) |
| T-08 | `workflow.sh status` | output byte-identical to baseline §9, exit 0 |
| T-09 | `workflow.sh bogus-subcommand` | usage on stdout, exit 1 — unchanged |
| T-10 | `from-issue.sh --help`; `-h`; no args | byte-identical to baseline §9, exit 0 |
| T-11 | `bash -n scripts/*.sh` | exit 0 for all six (syntax check, cheap and side-effect free) |
| T-12 | `test -s scripts/README.md` and read-through against §4 invocation syntax | exit 0, all six scripts documented |
| T-13 | `git status --porcelain` before/after T-01..T-11 in the temp copy | no tracked-file or `.workflow/` change from any help/version/unknown invocation |

Alternative considered and rejected: adding `tests/help_test.sh`. It would give
a re-runnable check, but CHANGE_SPEC §12 explicitly non-goals a test framework,
and a single untriggered script with no runner or CI is not meaningfully more
durable than the recorded matrix. Revisit if a runner is ever added.

## 13. Regression-test strategy

Not a bug fix, so there is no single pre-existing failure to pin. The nearest
equivalent — a check that fails before the change and passes after — is **T-05**:
`codex-review-plan.sh --help` and `codex-create-checklist.sh --help` produce no
output and exit 1 today (B-04, B-05), and must produce usage and exit 0 after.
T-07 is the second such check (`workflow.sh --help`: exit 1 → exit 0).

Pure regression guards, all of which must produce output identical to
BASELINE_REPORT §9: T-08, T-09, T-10. T-11 guards IV-06 (bash 3.2 parse), T-13
guards IV-07 (no side effects).

## 14. Manual-verification strategy

| ID | Check |
|---|---|
| MC-01 | Read the diff: every guard sits after `cd "$ROOT"` and before the first side-effecting statement in its file (IV-02, IV-07, IV-08) |
| MC-02 | Read the diff: `set -euo pipefail` and lines 1–5 unmodified in all six scripts (IV-01, IV-02) |
| MC-03 | Read the guards for bash 3.2 constructs only — no associative arrays, no `${var^^}`, no regex (IV-06); confirmed executable by T-11 |
| MC-04 | Read the diff: no new `WORKFLOW_*` read and no configuration flag added (IV-05) |
| MC-05 | Cross-read `scripts/README.md` against each script's actual arguments and each `usage()` text — no documented flag that does not exist, no flag that is not documented (AC-08) |
| MC-06 | Confirm the temp-copy containment of §11 was actually used for T-01..T-06, and that `claude`/`codex` were never invoked (no cost-ledger or log growth) |

A reviewer-authored `MANUAL_CHECKLIST.md` supersedes this list where they
conflict.

## 15. Observability changes

None to runtime logging. The only new operator-visible surface is the usage and
version text itself and `scripts/README.md`.

## 16. Implementation sequence

1. `scripts/codex-review-plan.sh` — guard (IV-08). Lowest blast radius;
   establishes the block that the other files copy.
2. `scripts/codex-create-checklist.sh` — same guard.
3. `scripts/workflow.sh` — extract `usage()`, add the `-h|--help|""` branch
   (IV-03 relaxation), leave `*)` semantics intact.
4. Run T-05..T-09, T-11 in place (these three scripts are safe to execute
   directly: they invoke no agent on the paths exercised, and T-09/T-08 match
   baseline behavior).
5. `scripts/stagegate.sh` — version literal + guard (IV-07). Highest blast
   radius; done after the pattern is proven.
6. `scripts/change-workflow.sh` — same.
7. Set up the §11 containment (temp copy, `WORKFLOW_*_CMD=false`), run
   T-01..T-04, T-11, T-13.
8. `scripts/README.md` — write from the finished `usage()` texts so the two
   cannot disagree; run T-12, MC-05.
9. Record deviations in `IMPLEMENTATION_NOTES.md`, results in
   `CHANGE_TEST_REPORT.md`.
10. OPT-01 (`README.md` pointer) last, only if steps 1–9 are clean.

## 17. Scope cuts under time pressure

Cut in this order:

1. OPT-01 — the `README.md` cross-link (not required by any AC; Core rule 5).
2. `--version` on both drivers (BH-02, BH-06 / AC-02) — the change request asks
   for help, not version; `--version` comes from Issue 9 only.
3. The `*)` unknown-argument branch on the two `codex-*` scripts (keep their
   `-h`/`--help` branch) — those scripts have no callers passing arguments.
4. `workflow.sh`'s IV-03 relaxation (BH-13) — leave it at exit 1, since it is
   the only behavior *change* in the set rather than an addition.

Never cut: `-h`/`--help` on all six scripts (the literal change request), and
`scripts/README.md` (AC-08).

## 18. Change-impact table

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/stagegate.sh` | Insert version literal, `usage()`, `case` guard at line 6 | BH-01/02/03, AC-01/02/04, IV-07 | Medium — 594-line driver, real spend on fall-through; mitigated by the `""` branch and §11 containment | T-01, T-02, T-04, T-11, T-13; MC-01..MC-04 |
| `scripts/change-workflow.sh` | Same | BH-05/06/07, AC-03/04, IV-07 | Medium — as above, plus cost ledger downstream | T-03, T-04, T-11, T-13; MC-01..MC-04 |
| `scripts/codex-review-plan.sh` | Insert `usage()` + guard above the `test -s` block | BH-09, AC-05, IV-08 | Low — 73 lines, no in-repo caller, zero-arg path untouched | T-05, T-06, T-11; MC-01 |
| `scripts/codex-create-checklist.sh` | Same | BH-11, AC-05, IV-08 | Low — as above | T-05, T-11; MC-01 |
| `scripts/workflow.sh` | Extract `usage()`; add `-h|--help|""` branch before `*)` | BH-13, AC-06, IV-03 (RELAXED) | Medium — only behavior *change* in the set; a mis-ordered branch could swallow `status`/`approve-*` | T-07, T-08, T-09, T-11; MC-01 |
| `scripts/from-issue.sh` | None | BH-16 PRESERVE | None | T-10 |
| `scripts/README.md` | New file | BH-17, AC-08 | None (new file) | T-12, MC-05 |
| `README.md` | OPT-01: one-line pointer (optional, first cut) | CONTRIBUTING.md doc convention | None | MC-05 |

## 19. Traceability

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| AC-01 | BH-01 | IV-07, IV-02 | `stagegate.sh` | T-01, T-13 | MC-01, MC-06 |
| AC-02 | BH-02 | IV-05 | `stagegate.sh` | T-02 | MC-04 |
| AC-03 | BH-05, BH-06 | IV-07, IV-02 | `change-workflow.sh` | T-03, T-13 | MC-01, MC-06 |
| AC-04 | BH-03, BH-07 | IV-07 | both drivers | T-04, T-13 | MC-01, MC-06 |
| AC-05 | BH-09, BH-11, BH-10, BH-12 | IV-08 | both `codex-*` scripts | T-05, T-06 | MC-01 |
| AC-06 | BH-13, BH-14, BH-15 | IV-03 (RELAXED) | `workflow.sh` | T-07, T-08, T-09 | MC-01 |
| AC-07 | BH-16 | IV-04 | `from-issue.sh` | T-10 | — |
| AC-08 | BH-17 | — | `scripts/README.md` | T-12 | MC-05 |
| AC-09 | BH-04, BH-08 | IV-05 | both drivers | T-13 (and T-01/T-03 no-mutation checks) | MC-04 |
| Spec §4 (bash 3.2) | all | IV-06 | all modified scripts | T-11 | MC-03 |
| Spec §4 (`set -euo pipefail`, `cd "$ROOT"` first) | all | IV-01, IV-02 | all modified scripts | T-11 | MC-02 |

## 20. Risks and unresolved questions

| ID | Item | Disposition |
|---|---|---|
| R-1 | A malformed guard lets `--bogus` fall through on a driver, starting a real billed run during verification | Mitigated by §11 containment (temp copy + `WORKFLOW_*_CMD=false`); implementer must not run T-04 in this working tree first |
| R-2 | `0.1.0` duplicated in two files drifts | Accepted for now; single literal per driver, named `STAGEGATE_VERSION`, documented in `scripts/README.md`. See Q-2. |
| R-3 | `scripts/README.md` and the `usage()` texts drift apart | Mitigated by sequence step 8 (write the doc from the finished usage texts) and MC-05; no automated enforcement exists |
| R-4 | `workflow.sh` help branch placed after `*)` or matching too broadly would break `status`/`approve-*` | T-08, T-09 are byte-comparison regression checks against BASELINE_REPORT §9 |
| R-5 | Baseline §13 asserts `run_codex` invokes the `codex-*` helpers; it does not (§8 above). If a caller is added later that passes arguments, the new `*)` branch would reject them | Recorded; no action — no such caller exists today |
| Q-1 | UNRESOLVED (reviewer decision): CHANGE_SPEC §4 says unknown arguments print usage to **stderr** on all six scripts, but BH-15 says `workflow.sh`'s unknown-subcommand path is **unchanged** (it prints to stdout today). Plan follows BH-15 and leaves that one path on stdout, so `workflow.sh` is the only script whose unknown-argument usage goes to stdout. | Confirm at the CHANGE_PLAN gate; if stderr is preferred, BH-15 must be reclassified MODIFY |
| Q-2 | UNRESOLVED (carried from CHANGE_SPEC §13): literal `0.1.0` per driver vs. a shared `VERSION` file read by both | Defaulting to the literal for minimal change surface; a `VERSION` file adds a read that must also be guarded against absence under `set -e` |
| Q-3 | Exact usage wording is implementer's choice (CHANGE_SPEC §13); the plan fixes only structure (script name, accepted arguments, pointer to `scripts/README.md`) | No action needed |
