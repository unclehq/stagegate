# Manual Verification Checklist

Base checks: 15; resolved: 1; added: 7; removed: 2

Check ID: MC-001
Priority: P0
Behavior classification: ADD
Related behavior: BH-01, BH-05 — both workflow drivers provide `-h` and `--help`.
Related invariant: IV-02, IV-07
Preconditions: Clean detached verification worktree with no `.workflow` path; `WORKFLOW_AGENT_CMD=false` and `WORKFLOW_REVIEWER_CMD=false`; stdout and stderr captured separately.
Exact action: Run `./scripts/stagegate.sh -h`, `./scripts/stagegate.sh --help`, `./scripts/change-workflow.sh -h`, and `./scripts/change-workflow.sh --help`, checking `.workflow` absence before and after each invocation.
Expected result: Every invocation exits 0; stdout contains a short usage summary naming the invoked script and its accepted arguments; stderr is empty; `.workflow` remains absent; no state-machine iteration or external agent command occurs.
Evidence to capture: Command lines, stdout, stderr, exit statuses, before/after `.workflow` absence assertions, process-invocation audit, and unchanged cost-ledger/log evidence.
Actual result:
Status: NOT RUN

Check ID: MC-002
Priority: P0
Behavior classification: ADD
Related behavior: BH-02, BH-06 — driver version reporting.
Related invariant: IV-05, IV-07
Preconditions: Same isolated worktree and disabled agent commands as MC-001; no `.workflow` path.
Exact action: Run `./scripts/stagegate.sh --version` and `./scripts/change-workflow.sh --version`, capturing stdout and stderr separately and checking `.workflow` before and after each command.
Expected result: Each command exits 0; stdout is exactly `0.1.0` followed by one newline; stderr is empty; no `.workflow` path is created; no configuration, precondition, state-machine, network, or external-agent work occurs.
Evidence to capture: Byte-level stdout capture, stderr, exit statuses, `.workflow` assertions, and process/cost-ledger audit.
Actual result:
Status: NOT RUN

Check ID: MC-003
Priority: P0
Behavior classification: ADD
Related behavior: BH-03, BH-07 — unknown and trailing driver arguments are rejected.
Related invariant: IV-07
Preconditions: Same isolated worktree and disabled agent commands as MC-001; no `.workflow` path.
Exact action: Run `./scripts/stagegate.sh --bogus`, `./scripts/stagegate.sh --help extra`, `./scripts/change-workflow.sh --bogus`, and `./scripts/change-workflow.sh --version extra`, checking `.workflow` absence before and after every invocation.
Expected result: Every command exits 1; stdout is empty; stderr identifies the invalid input and includes usage for the invoked script; recognized flags with trailing arguments are rejected; no `.workflow` path, external-agent invocation, cost-ledger change, or state-machine iteration occurs.
Evidence to capture: Command lines, stdout, stderr, exit statuses, direct `.workflow` assertions, process audit, and cost-ledger/log before-and-after comparison.
Actual result:
Status: NOT RUN

Check ID: MC-004
Priority: P0
Behavior classification: ADD
Related behavior: BH-09, BH-11 — Codex helper help paths.
Related invariant: IV-08
Preconditions: Clean isolated worktree in which the helpers’ normal precondition files are deliberately absent; stdout and stderr captured separately.
Exact action: Run `./scripts/codex-review-plan.sh -h`, `./scripts/codex-review-plan.sh --help`, `./scripts/codex-create-checklist.sh -h`, and `./scripts/codex-create-checklist.sh --help`.
Expected result: Every invocation exits 0; usage appears only on stdout; stderr is empty; each output contains its invoked script’s basename and does not contain the other helper’s basename; missing precondition files do not cause failure; Codex is not invoked.
Evidence to capture: Preconditions showing relevant files absent, stdout, stderr, exit statuses, basename assertions, and process-invocation audit.
Actual result:
Status: NOT RUN

Check ID: MC-005
Priority: P0
Behavior classification: ADD
Related behavior: BH-09, BH-11 — Codex helper unknown-argument handling.
Related invariant: IV-08
Preconditions: Same missing-precondition-file fixture as MC-004; stdout and stderr captured separately.
Exact action: Run `./scripts/codex-review-plan.sh --bogus`, `./scripts/codex-review-plan.sh --help extra`, `./scripts/codex-create-checklist.sh --bogus`, and `./scripts/codex-create-checklist.sh --help extra`.
Expected result: Every invocation exits 1; stdout is empty; stderr contains basename-correct usage; trailing arguments are rejected; no precondition check failure supersedes the argument error; Codex is not invoked.
Evidence to capture: Stdout, stderr, exit statuses, basename assertions, precondition fixture state, and process-invocation audit.
Actual result:
Status: NOT RUN

Check ID: MC-007
Priority: P0
Behavior classification: PRESERVE
Related behavior: BH-14, BH-15 — `workflow.sh` status and invalid-subcommand behavior.
Related invariant: IV-03 (RELAXED only for empty/help cases)
Preconditions: Golden stdout, stderr, and exit-status fixtures captured from the frozen pre-change revision for `status` and an unknown subcommand; equivalent isolated pre- and post-change worktrees.
Exact action: Run `./scripts/workflow.sh status` and `./scripts/workflow.sh bogus-subcommand` in the post-change fixture and compare each stream and exit status byte-for-byte with its pre-change golden fixture.
Expected result: `status` remains byte-identical and exits 0; the unknown subcommand remains byte-identical, writes usage to stdout, and exits 1; the stderr streams remain unchanged.
Evidence to capture: Golden and candidate files, `cmp` results for both streams, exit-status comparisons, and resulting filesystem state.
Actual result:
Status: NOT RUN

Check ID: MC-008
Priority: P0
Behavior classification: PRESERVE
Related behavior: BH-14 — all approval subcommands retain their prior behavior.
Related invariant: IV-03
Preconditions: Equivalent disposable pre- and post-change worktrees; for `approve-plan`, create identical non-empty `PROJECT_PLAN.md` files; for `approve-review`, create identical non-empty `ADVERSARIAL_REVIEW.md` files; for `approve-updated-plan`, create identical non-empty `UPDATED_PROJECT_PLAN.md` files; keep each worktree’s `.workflow/approvals` isolated from the repository; capture stdout, stderr, exit status, and filesystem state.
Exact action: In both revisions run each approval subcommand three times from a reset fixture: pipe `APPROVE\n` with its required file present and non-empty; run with its required file absent; and pipe `REJECT\n` with its required file present and non-empty; compare corresponding stdout, stderr, exit status, `.workflow/approvals/<name>.sha256`, and required-file SHA-256 values byte-for-byte.
Expected result: Each post-change result is byte-identical to its pre-change counterpart; successful approval writes exactly the required file’s SHA-256 and the existing success/next-step output; a missing file exits 1 without an approval record; non-`APPROVE` input exits 1 without an approval record; no subcommand is swallowed by the new help dispatch.
Evidence to capture: Fixture manifest, exact input bytes, commands, pre/post streams and statuses, `cmp` results, approval-directory manifests, generated approval files, and independent `shasum -a 256` comparisons.
Actual result:
Status: NOT RUN

Check ID: MC-009
Priority: P0
Behavior classification: PRESERVE
Related behavior: BH-04, BH-08, BH-10, BH-12 — existing zero-argument execution paths.
Related invariant: IV-05, IV-07, IV-08
Preconditions: Equivalent isolated pre- and post-change worktrees; driver agent/reviewer commands set to `false`; helper precondition fixtures identical between revisions; no real credentials or billable commands available.
Exact action: Run zero-argument `stagegate.sh`, `change-workflow.sh`, `codex-review-plan.sh`, and `codex-create-checklist.sh` once in each revision, stopping at the same stubbed-command or precondition boundary and comparing stdout, stderr, exit status, and filesystem effects.
Expected result: For every script, pre-change and post-change observations are identical through the controlled failure boundary; zero arguments do not display help in the two drivers or Codex helpers and do not alter their normal dispatch.
Evidence to capture: Fixture manifest, environment, command transcripts, stream/status comparisons, filesystem snapshots, and proof no real external command ran.
Actual result:
Status: NOT RUN

Check ID: MC-010
Priority: P1
Behavior classification: PRESERVE
Related behavior: BH-16 — existing `from-issue.sh` help behavior.
Related invariant: IV-04
Preconditions: Golden stdout, stderr, and exit-status fixtures captured from the frozen pre-change revision for no arguments, `-h`, and `--help`.
Exact action: Run `./scripts/from-issue.sh`, `./scripts/from-issue.sh -h`, and `./scripts/from-issue.sh --help`; compare each result byte-for-byte with its corresponding golden fixture.
Expected result: All three forms remain byte-identical, print usage to stdout, leave stderr unchanged, and exit 0.
Evidence to capture: Golden and candidate outputs, exit statuses, and `cmp` results.
Actual result:
Status: NOT RUN

Check ID: MC-011
Priority: P1
Behavior classification: ADD
Related behavior: BH-17 — consolidated scripts invocation documentation.
Related invariant: IV-04, IV-05
Preconditions: Post-change checkout containing `scripts/README.md`.
Exact action: Confirm `scripts/README.md` is non-empty; inspect it for one entry for each of the six script basenames; compare every documented invocation and flag with the corresponding command’s observed help output.
Expected result: All six scripts have a one-line purpose and exact invocation syntax; only the two workflow drivers document `--version`; every command documents `-h` and `--help`; zero-argument and subcommand syntax matches specified behavior; the stdout exception for unknown `workflow.sh`/`from-issue.sh` input is documented; no nonexistent flag is advertised.
Evidence to capture: Documentation review record, six-script coverage matrix, and documentation-to-help comparison.
Actual result:
Status: NOT RUN

Check ID: MC-012
Priority: P1
Behavior classification: PRESERVE
Related behavior: All modified shell-script behaviors.
Related invariant: IV-01, IV-02, IV-06
Preconditions: Post-change checkout with Bash 3.2 available.
Exact action: Run `for f in scripts/*.sh; do bash -n "$f" || exit 1; done` under Bash 3.2, recording each filename and result.
Expected result: All six scripts parse successfully as separate files; no associative arrays, `${var^^}`, lazy regular expressions, or other Bash-post-3.2 syntax prevents parsing.
Evidence to capture: Bash version and complete per-file syntax-check transcript.
Actual result:
Status: NOT RUN

Check ID: MC-014
Priority: P1
Behavior classification: PRESERVE
Related behavior: CLI relocatability and unchanged environment-based configuration.
Related invariant: IV-02, IV-05
Preconditions: Isolated checkout; a caller working directory outside the repository; agent/reviewer commands disabled.
Exact action: Invoke each script’s help form by absolute path from outside the repository; invoke both drivers with zero arguments under the same controlled environment used by MC-009.
Expected result: Help commands resolve the repository root and succeed from the foreign working directory; controlled zero-argument driver behavior matches the pre-change fixture; no new configuration CLI flag or required environment variable is introduced.
Evidence to capture: Caller working directory, absolute commands, environment manifest, stdout, stderr, exit statuses, and pre/post comparison.
Actual result:
Status: NOT RUN

Check ID: MC-015
Priority: P1
Behavior classification: ROLLBACK
Related behavior: Entire additive help/version/documentation change.
Related invariant: No migration or persistent-format change
Preconditions: Disposable worktree containing the completed change and an identified change commit; verification artifacts from MC-001 through MC-014 retained.
Exact action: Revert the change commit in the disposable worktree, confirm `scripts/README.md` is removed and the five modified scripts return to their frozen pre-change behavior, then rerun the preserved-behavior comparisons.
Expected result: Rollback requires no data conversion or state repair; pre-change CLI behavior and golden comparisons are restored; existing workflow state, approval hashes, prompts, logs, and cost-ledger formats remain readable and unchanged.
Evidence to capture: Revert command and status, post-revert file inventory, preserved-behavior comparison results, and state/artifact integrity checks.
Actual result:
Status: NOT RUN

Check ID: MC-016
Priority: P0
Behavior classification: DEVIATION
Related behavior: BH-13 — narrowed `workflow.sh` help behavior; IMPLEMENTATION_NOTES.md:34.
Related invariant: IV-03 (RELAXED only for explicit help flags), IV-02
Preconditions: Clean isolated worktree with no `.workflow` path; stdout and stderr captured separately; no explicit approval of the bare-zero-argument IV-03 relaxation exists, as recorded in IMPLEMENTATION_NOTES.md:37.
Exact action: Separately run `./scripts/workflow.sh -h`, `./scripts/workflow.sh --help`, and `./scripts/workflow.sh`; assert `.workflow/approvals` absence before and after each help-flag invocation, and compare the zero-argument stdout, stderr, and exit status byte-for-byte with the frozen pre-change golden fixture.
Expected result: `-h` and `--help` exit 0, write usage only to stdout, list `approve-plan`, `approve-review`, `approve-updated-plan`, and `status`, and do not create `.workflow/approvals`; the zero-argument invocation remains byte-identical to the baseline, exits 1, writes usage to stdout, leaves stderr empty, and follows the preserved side-effect ordering described in IMPLEMENTATION_NOTES.md:48.
Evidence to capture: Approval-record search, commands, stdout, stderr, exit statuses, `cmp` results, and before/after `.workflow/approvals` assertions.
Actual result:
Status: NOT RUN

Check ID: MC-017
Priority: P0
Behavior classification: MODIFY
Related behavior: BH-14 boundary — recognized `workflow.sh` subcommands with trailing arguments are now rejected; IMPLEMENTATION_NOTES.md:66.
Related invariant: IV-03, IV-07
Preconditions: Disposable isolated worktree; stdout and stderr captured separately; snapshots of `.workflow/approvals` and all approval-input files; no real approval state in scope.
Exact action: Run `./scripts/workflow.sh status extra`, `./scripts/workflow.sh approve-plan extra`, `./scripts/workflow.sh approve-review extra`, and `./scripts/workflow.sh approve-updated-plan extra`, supplying `APPROVE\n` on stdin and resetting the fixture between invocations.
Expected result: Every command exits 1 and writes the existing usage text to stdout with empty stderr; no status inspection or approval prompt occurs; no approval hash is created or changed; no approval-input file is changed; only the preserved early `mkdir -p .workflow/approvals` side effect may occur.
Evidence to capture: Commands, stdin, stdout, stderr, exit statuses, prompt-absence assertion, and before/after hashes and directory manifests.
Actual result:
Status: NOT RUN

Check ID: MC-018
Priority: P0
Behavior classification: PRESERVE
Related behavior: BH-04, BH-08 — driver state machines beyond argument handling.
Related invariant: IV-02, IV-05, IV-07
Preconditions: Equivalent disposable pre- and post-change worktrees with identical approved workflow fixtures for every reachable stage; deterministic non-billable agent and reviewer stubs that record argv/stdin and create the exact expected stage output files; identical environment configuration.
Exact action: Resume `stagegate.sh` and `change-workflow.sh` from each reachable persisted stage in both revisions, allowing each deterministic stubbed state-machine step to complete, and compare stdout, stderr, exit status, stub invocation records, generated artifacts, workflow state, logs, and cost-ledger files after every step.
Expected result: Corresponding pre- and post-change runs are byte-identical; the new argument guards do not alter zero-argument state dispatch, restart/resume behavior, agent or reviewer selection, prompts, artifacts, logs, approvals, state transitions, or accounting.
Evidence to capture: Fixture and stub definitions, starting-state manifest, command transcripts, per-stage stream/status comparisons, invocation records, and recursive artifact hashes.
Actual result:
Status: NOT RUN

Check ID: MC-019
Priority: P0
Behavior classification: PRESERVE
Related behavior: BH-10, BH-12 — Codex helper execution after satisfied preconditions.
Related invariant: IV-05, IV-08
Preconditions: Equivalent disposable pre- and post-change worktrees; identical non-empty required Markdown files; matching approval SHA-256 records; deterministic `WORKFLOW_REVIEWER_CMD` stub that records argv and prompt and writes a non-empty file to the `--output-last-message` path.
Exact action: Run zero-argument `codex-review-plan.sh` and `codex-create-checklist.sh` once in each revision, then compare stdout, stderr, exit status, reviewer-stub argv and prompt, `ADVERSARIAL_REVIEW.md` or `MANUAL_CHECKLIST.md`, approval files, and all other filesystem effects.
Expected result: Each post-change execution is byte-identical to its pre-change counterpart; satisfied preconditions reach the reviewer exactly once; output-path and sandbox arguments are unchanged; each expected output file is non-empty; guards do not intercept the zero-argument path.
Evidence to capture: Fixture hashes, stub implementation and invocation log, commands, streams, statuses, output artifacts, approval records, and pre/post filesystem comparisons.
Actual result:
Status: NOT RUN

Check ID: MC-020
Priority: P1
Behavior classification: PRESERVE
Related behavior: BH-16 — `from-issue.sh` real issue-argument path.
Related invariant: IV-04
Preconditions: Equivalent disposable pre- and post-change worktrees; authenticated `gh` access or a controlled command-path fixture returning deterministic issue JSON for a known issue; snapshots of `CHANGE_REQUEST.md` and `REQUIREMENTS.md`.
Exact action: Run `./scripts/from-issue.sh <issue-number-or-url> --change` and `./scripts/from-issue.sh <issue-number-or-url> --new` in reset pre- and post-change fixtures using the same issue response, then compare stdout, stderr, exit status, fetched issue identity, and generated documents byte-for-byte.
Expected result: Corresponding results are byte-identical; issue parsing, mode selection, error visibility, and generated document content are unchanged; no help-related change affects a valid issue argument.
Evidence to capture: Issue identifier and response hash, authentication or controlled-fixture details, commands, streams, statuses, and pre/post document comparisons.
Actual result:
Status: NOT RUN

Check ID: MC-021
Priority: P1
Behavior classification: ADD
Related behavior: BH-17 — top-level documentation pointer added by OPT-01; IMPLEMENTATION_NOTES.md:25.
Related invariant: IV-04
Preconditions: Post-change checkout containing `README.md` and `scripts/README.md`.
Exact action: Follow the `scripts/README.md` link in the top-level README’s Manual helpers section and compare its stated “all six scripts” scope with the six entries checked by MC-011.
Expected result: The relative link resolves to the non-empty `scripts/README.md`; its link text and surrounding claim accurately describe the target; all six script entries are present and no script is counted twice.
Evidence to capture: README.md:286 link text and target, link-resolution result, and six-script inventory.
Actual result:
Status: NOT RUN

Check ID: MC-022
Priority: P0
Behavior classification: ADD
Related behavior: All help, version, and newly guarded error paths, including the narrowed `workflow.sh` deviation.
Related invariant: IV-07, IV-08
Preconditions: Clean detached worktree with no `.workflow`; disabled agent/reviewer commands; process monitoring and filesystem snapshots available.
Exact action: Execute MC-001 through MC-005 and the `workflow.sh -h`/`--help` portions of MC-016 while monitoring child processes and comparing tracked files, `.workflow`, logs, approvals, and cost-ledger state before and after every invocation.
Expected result: No `claude` or `codex` process starts; no network-dependent workflow work begins; no tracked file changes; no `.workflow`, log, approval, state, or cost-ledger file is created or enlarged.
Evidence to capture: Process-monitor output, before/after filesystem manifests, tracked-file status, cost-ledger/log sizes, and direct `.workflow` assertions.
Actual result:
Status: NOT RUN

Acceptance-criteria traceability: AC-01→MC-001,MC-003,MC-022; AC-02→MC-002; AC-03→MC-001,MC-002,MC-003,MC-022; AC-04→MC-003,MC-022; AC-05→MC-004,MC-005,MC-009,MC-019; AC-06→MC-007,MC-008,MC-016,MC-017; AC-07→MC-010,MC-020; AC-08→MC-011,MC-021; AC-09→MC-009,MC-014,MC-018.
Preserved-behavior coverage: BH-04/BH-08→MC-009,MC-018; BH-10/BH-12→MC-009,MC-019; BH-14→MC-007,MC-008; BH-15→MC-007; BH-16→MC-010,MC-020; relocatability/configuration→MC-014; rollback compatibility→MC-015.
Changed-behavior coverage: BH-01/BH-05→MC-001; BH-02/BH-06→MC-002; BH-03/BH-07→MC-003; BH-09/BH-11→MC-004,MC-005; narrowed BH-13→MC-016; BH-14 trailing-argument boundary→MC-017; BH-17→MC-011,MC-021.
Invariant coverage: IV-01→MC-012; IV-02→MC-001,MC-012,MC-014,MC-016,MC-018; IV-03→MC-007,MC-008,MC-016,MC-017; IV-04→MC-010,MC-011,MC-020,MC-021; IV-05→MC-002,MC-009,MC-011,MC-014,MC-018,MC-019; IV-06→MC-012; IV-07→MC-001,MC-002,MC-003,MC-017,MC-018,MC-022; IV-08→MC-004,MC-005,MC-009,MC-019,MC-022.
Regression coverage: Driver fall-through, full state-machine behavior, and billable-work prevention→MC-001,MC-003,MC-009,MC-018,MC-022; workflow dispatch/approval behavior→MC-007,MC-008,MC-016,MC-017; helper preconditions and satisfied execution→MC-004,MC-005,MC-009,MC-019; existing `from-issue.sh` behavior→MC-010,MC-020; Bash 3.2 compatibility→MC-012; documentation drift→MC-011,MC-021; relocatability and environment configuration→MC-014; rollback NOT RUN gap→MC-015.
Removed checks: MC-006 — provably inapplicable because its explicit-approval precondition is unmet and the implemented narrow branch deliberately preserves zero-argument exit 1 (IMPLEMENTATION_NOTES.md:34); replaced by MC-016. MC-013 — its exact action requires deleted MC-006 and therefore cannot be executed as written; its still-applicable containment coverage is replaced by MC-022.