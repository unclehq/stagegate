## AR-001: `workflow.sh --help` remains side-effecting

- Severity: High
- Affected behavior: BH-13 / AC-06
- Affected invariant: Spec §4 early-exit/no-side-effect contract, omitted from IV-07 and IV-08
- Affected component: `scripts/workflow.sh`
- Failure scenario: Running `workflow.sh --help` in a clean repository creates `.workflow/approvals` before printing help.
- Evidence: `scripts/workflow.sh:7` executes `mkdir -p` before dispatch at line 37; CHANGE_PLAN §5 explicitly preserves this ordering despite CHANGE_SPEC §§4 and 9 requiring help handling before side effects.
- Why current tests may miss it: T-07 checks only output and status, while T-13 uses `git status`, which cannot see the gitignored `.workflow` directory.
- Recommended correction: Parse help immediately after `cd "$ROOT"` and before `mkdir -p`, or explicitly narrow the specification and acceptance criteria.
- Proposed verification: In a clean fixture, run every help path and assert `test ! -e .workflow` afterward.
- Blocks implementation: Yes

## AR-002: The uniform unknown-argument contract is not implemented

- Severity: High
- Affected behavior: Spec §4 unknown-argument handling, BH-15, BH-16
- Affected invariant: Unknown arguments must produce usage on stderr and exit non-zero
- Affected component: `scripts/from-issue.sh`, `scripts/workflow.sh`
- Failure scenario: `from-issue.sh 123 --bogus` and `workflow.sh bogus` print usage to stdout, contradicting the promised all-six-scripts stderr contract.
- Evidence: `scripts/from-issue.sh:39` and `scripts/workflow.sh:75-84` use stdout; the plan leaves both unchanged and records the `workflow.sh` conflict as unresolved Q-1.
- Why current tests may miss it: T-09 expects the conflicting stdout behavior, while T-10 never exercises an unknown argument to `from-issue.sh`.
- Recommended correction: Resolve whether uniform stderr behavior or backward compatibility governs, then update the spec, behavior classifications, plan, and tests consistently.
- Proposed verification: Capture stdout and stderr separately for an unknown argument on all six scripts and assert exact status and stream placement.
- Blocks implementation: Yes

## AR-003: The `workflow.sh` no-argument relaxation lacks authorization

- Severity: High
- Affected behavior: BH-13 / AC-06
- Affected invariant: IV-03
- Affected component: `scripts/workflow.sh`
- Failure scenario: A caller using no arguments as an invalid-invocation check currently receives exit 1 but would begin receiving exit 0.
- Evidence: BASELINE_REPORT B-02 marks the current result “Must preserve: Yes”; CHANGE_REQUEST.md requests help but does not request successful no-argument invocation; CHANGE_SPEC §13 says explicit approval is required, while CHANGE_PLAN §8 asserts approval without recording evidence.
- Why current tests may miss it: T-07 proves the newly selected behavior rather than detecting the backward-compatibility break.
- Recommended correction: Keep no-argument invocation at exit 1 and add only `-h`/`--help`, unless the approval authority explicitly accepts the relaxation.
- Proposed verification: Assert no arguments exit 1, explicit help exits 0, and both print the intended usage text.
- Blocks implementation: Yes

## AR-004: The syntax-check command checks only one script

- Severity: Medium
- Affected behavior: T-11
- Affected invariant: IV-06
- Affected component: All `scripts/*.sh` files
- Failure scenario: A syntax error in any script other than the first glob expansion is not parsed by `bash -n scripts/*.sh`.
- Evidence: Bash treats the first expanded filename as the script and the remaining filenames as positional arguments; CHANGE_PLAN T-11 incorrectly claims this verifies all six scripts.
- Why current tests may miss it: The command can exit 0 while five scripts were never syntax-checked.
- Recommended correction: Loop over the files and run `bash -n "$file"` independently, failing on the first non-zero result.
- Proposed verification: Introduce a syntax error into a non-first temporary fixture and demonstrate that the corrected loop fails.
- Blocks implementation: No

## AR-005: Inspecting only `$1` accepts invalid trailing arguments

- Severity: Medium
- Affected behavior: BH-01 through BH-15
- Affected invariant: Spec §4 rejection of any unrecognized flag or argument
- Affected component: All proposed argument guards
- Failure scenario: `stagegate.sh --help --bogus`, `change-workflow.sh --version extra`, and `workflow.sh status extra` succeed while silently ignoring invalid arguments.
- Evidence: CHANGE_PLAN §1 fixes the guard to `$1` only, and §9 explicitly accepts ignored trailing arguments despite the specification’s broader wording.
- Why current tests may miss it: T-01 through T-10 exercise only single-argument forms.
- Recommended correction: Define accepted arity explicitly and validate `$#`; if trailing arguments are intentionally ignored, narrow the specification and classify existing command-plus-extra behavior as PRESERVE.
- Proposed verification: Test recognized commands and flags with one and multiple trailing arguments, including `--help --bogus`.
- Blocks implementation: Yes

## AR-006: Preserved zero-argument behavior is never verified

- Severity: Medium
- Affected behavior: BH-04, BH-08, BH-10, BH-12 / AC-09
- Affected invariant: Existing zero-argument execution must remain unchanged
- Affected component: Both drivers and both `codex-*` helpers
- Failure scenario: A copied guard accidentally routes the empty case to usage or exits non-zero, yet every planned help, version, and unknown-argument check behaves correctly.
- Evidence: The change-impact table cites T-13 for driver preservation, but T-13 runs T-01 through T-11 and none executes either driver or helper with zero arguments.
- Why current tests may miss it: Filesystem cleanliness after flag invocations does not exercise the preserved fall-through path.
- Recommended correction: Compare pre-change and post-change zero-argument executions in identical isolated fixtures with external commands stubbed.
- Proposed verification: Record exit status, stdout, stderr, invoked stub arguments, and filesystem changes for each zero-argument entry point before and after the change.
- Blocks implementation: Yes

## AR-007: The containment oracle can conceal `.workflow` mutations

- Severity: Medium
- Affected behavior: T-13 and MC-06
- Affected invariant: IV-07 and IV-08 no-side-effect guarantees
- Affected component: Verification environment
- Failure scenario: A `cp -R` fixture carries the repository’s existing `.workflow` directory, and a broken help guard mutates it without affecting `git status --porcelain`.
- Evidence: BASELINE_REPORT §11 records an existing `.workflow`; CHANGE_PLAN §11 permits `cp -R`; `.gitignore:1` ignores the entire directory.
- Why current tests may miss it: Both pre-existing directories and ignored-file mutations defeat the proposed creation and Git-status signals.
- Recommended correction: Use a clean `git worktree` or archive fixture, assert `.workflow` is absent before each invocation, and snapshot the filesystem directly rather than through Git.
- Proposed verification: Compare `find .workflow` output or assert complete absence before and after each help, version, and unknown-argument command.
- Blocks implementation: Yes

## AR-008: Usage tests can pass copy-pasted or incorrect help

- Severity: Medium
- Affected behavior: AC-01, AC-03, AC-05, AC-08
- Affected invariant: Help must name the correct script and accepted arguments
- Affected component: Five new `usage()` functions and `scripts/README.md`
- Failure scenario: `codex-create-checklist.sh --help` prints the copied `codex-review-plan.sh` usage and still satisfies T-05’s generic “usage text” expectation.
- Evidence: The plan uses repeated inline guards, T-05 does not specify content assertions, T-06 omits `codex-create-checklist.sh --bogus`, and T-12 is only a non-empty-file check plus subjective read-through.
- Why current tests may miss it: Exit status and non-empty output do not prove the script name, synopsis, supported flags, stream, or documentation agree.
- Recommended correction: Define exact or pattern-based assertions for every synopsis and add unknown-argument coverage for both helpers.
- Proposed verification: Assert each help output contains its own basename and exact accepted syntax, rejects another script’s syntax, and matches its README entry.
- Blocks implementation: No

## AR-009: Byte-identical regression checks have no reproducible baseline

- Severity: Medium
- Affected behavior: BH-14, BH-15, BH-16
- Affected invariant: Preserved command output must remain byte-identical
- Affected component: T-08, T-09, T-10
- Failure scenario: Whitespace, blank lines, or stream placement changes while a reviewer compares only against the prose summary in BASELINE_REPORT §9.
- Evidence: The baseline records summarized results but no captured stdout/stderr fixtures or hashes; the plan nevertheless requires byte comparison against that section.
- Why current tests may miss it: A prose description cannot serve as a byte-level comparison operand.
- Recommended correction: Capture pre-change stdout, stderr, and exit status from controlled fixtures, then run the modified scripts against identical fixtures and compare files with `cmp`.
- Proposed verification: Produce separate golden captures for `workflow.sh status`, unknown workflow commands, and all preserved `from-issue.sh` help forms.
- Blocks implementation: No

- Blocking findings: AR-001, AR-002, AR-003, AR-005, AR-006, and AR-007.
- Regression risks: Side-effecting help, changed no-argument semantics, silently accepted trailing arguments, inconsistent error streams, and unverified fall-through behavior.
- Recommended simplifications: Keep `workflow.sh` no-argument behavior unchanged; limit the core change to explicit help plus `scripts/README.md`; omit `--version` unless the separate Issue 9 scope is explicitly approved.
- Required test additions: Exact stdout/stderr/status matrices for all six scripts, trailing-argument cases, unknown arguments on both helpers and `from-issue.sh`, isolated zero-argument before/after comparisons, direct filesystem snapshots, and a per-file `bash -n` loop.
- Overall assessment: Not ready for implementation; the plan contains unresolved contract contradictions and its verification strategy cannot prove several central acceptance criteria.