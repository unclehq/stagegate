# Change Test Report

Host: darwin 25.5.0, bash 3.2 system shell, `shasum -a 256`, BSD `script`.
All commands run from the repository root.

## Baseline

- `bash scripts/tests/close-flow-test.sh` (pre-change, current tree) — exit 0, 181 checks passed. Matches BASELINE §9.
- `bash scripts/tests/gate-prompt-test.sh` (pre-change) — exit 2, G1 failed as designed (`y` produced `Approval cancelled.`, exit 1, no approval file) and the G2 extraction aborted on the absent helpers. Confirms the new suite has teeth (plan §28).

## Targeted tests

- `bash scripts/tests/gate-prompt-test.sh` — exit 0, 235 checks passed, 0 not run. Covers G1 (`workflow.sh`), G2 (`change-workflow.sh` `human_gate` at all four real call sites), G3 (`stagegate.sh` `review_and_approve` at all four real call sites), G4 (styling), G5 (whitespace).

## Regression tests

- `bash scripts/tests/close-flow-test.sh` — exit 0, 181 checks passed, unchanged from baseline; file not edited.
- `bash scripts/tests/audit-verdict-test.sh` — exit 0, 26 checks passed, unchanged from baseline.
- `bash scripts/tests/agent-kimi-test.sh` — exit 0, 23 checks passed, unchanged from baseline.

## Full test suite

- All four suites above, 465 checks total, exit 0 each. No suite was skipped.

## Formatting

- N/A (no formatter is configured in this repository; BASELINE §8 lists no format step).

## Compiler or type checker

- N/A (shell project, no compiler). Closest equivalent recorded under linting: `bash -n scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh` — exit 0, syntax ok for all scripts.

## Linting

- `shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh` — exit 1. Findings are exactly the BASELINE §10 set: `SC2034` (`attempt` unused, `scripts/change-workflow.sh`, now line 201 after the added helpers), `SC2317` (`scripts/from-issue.sh:200`), `SC2148` (`scripts/lib/audit-verdict.sh:1`), `SC1091` (`scripts/lib/issue-close.sh:18`), `SC2059` info (`scripts/tests/audit-verdict-test.sh:21`).
- `shellcheck -f gcc scripts/change-workflow.sh scripts/stagegate.sh scripts/workflow.sh scripts/tests/gate-prompt-test.sh` — exit 1; the only findings are the pre-existing `SC2034` and three `SC1091` "not following sourced file" notes. `scripts/stagegate.sh`, `scripts/workflow.sh`, and the new suite are clean. No new finding.
- Discrepancy to note: BASELINE §9 records `shellcheck` "exited 0". The `SC2148` error in `scripts/lib/audit-verdict.sh` makes it exit 1, and that file is unmodified — `shellcheck` on the `HEAD` copy of `scripts/lib/audit-verdict.sh` alone also exits 1. The non-zero status is pre-existing, not introduced here; the baseline's exit-status line was inaccurate.

## Integration tests

- `bash scripts/tests/close-flow-test.sh` — exit 0. This suite runs the real `scripts/change-workflow.sh` in a scratch repo with stubbed `gh` and agent CLIs (lock, origin binding, verdict recording, issue-close matrix). No scenario reaches a `human_gate`, so the gate change did not require any edit to the suite (plan §14 verification step, R-6 closed).

## Frontend build

- N/A (no frontend in this repository).

## Migration tests

- N/A (no state or data migration; the approval path `.workflow/approvals/<name>.sha256` and its one-digest-per-line format are unchanged, asserted by `expect_hash_of` in G1/G2/G3).

## Rollback test

- NOT RUN. Plan §11's rollback is a single-commit revert; the change is uncommitted, so no commit exists to revert. `git status` was used to confirm the change is confined to the six §23 files plus the two report artifacts, which is what makes the revert single-commit-safe, but the revert itself was not executed.

## Performance checks

- N/A (interactive gate; the change adds one `shasum -a 256` per gated file per gate, at most four per gate, on files of a few kilobytes). No performance budget exists in CHANGE_SPEC.md.

## Security checks

- Approval-record integrity is the security surface of this change and is asserted, not assumed: G1/G2/G3 compare each `.workflow/approvals/<name>.sha256` byte-for-byte against `shasum -a 256` of the file shown at the prompt, and assert the file-name-to-approval-name mapping at every multi-file gate.
- Race coverage: `g1-race` (real FIFO), `g2-race`, `g3-reopen-on-edit`, and `g3-race-after-response` confirm a document mutated between the displayed digest and the recording step never produces an approval file containing the unreviewed digest.
- Decline coverage: `n`, `N`, arbitrary text, empty line, leading space, trailing space, EOF at the Y/N read, and EOF at the preliminary read all decline with the preserved exit code (0 for the two drivers, 1 for `workflow.sh`) and write no approval file.
- No new permission-bypass flag, environment variable, or configuration knob was introduced.

## Newly introduced warnings

- None. The `SC2034` line number moved from 179 to 201 because helper functions were added above it; the finding itself is pre-existing and unrelated.

## Pre-existing failures

- None in the test suites. The pre-existing `shellcheck` findings and its non-zero exit status are listed under Linting.

## Untested areas

- Manual checks M-1…M-8 (plan §15): not covered by this report; they belong to `VERIFICATION_REPORT.md`.
- Live end-to-end driver runs of `change-workflow.sh` and `stagegate.sh` through a real gate with real agent CLIs. G2/G3 exercise the gate functions verbatim via the extraction harness (IMPLEMENTATION_NOTES D-1) and `close-flow-test.sh` exercises the driver's preflight, but no automated test drives a full pipeline to a gate.
- The caller-side effect of `cancel_speculation` in `stagegate.sh`: stubbed in the G3 harness, so the suite asserts that the re-open path invokes it, not what it does. Covered manually by M-4.
- `scripts/README.md:78` retains "the exact word `RUN`". This is the preserved `from-issue.sh` gate (criterion 5, I-1a), not a stale approval-gate instruction; see IMPLEMENTATION_NOTES D-3. Acceptance criterion 9's literal grep therefore still matches that line.
- Doc grep executed: `grep -rnE 'exact word|requested word|Type (APPROVE|ACKNOWLEDGE)|APPROVE|ACKNOWLEDGE' README.md QUICK_START.md scripts/README.md` — the single remaining hit is `scripts/README.md:78` above. `README.md` and `QUICK_START.md` are clean.
