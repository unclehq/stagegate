# Implementation Notes

Approved plan: UPDATED_CHANGE_PLAN.md (frozen scope §22, file list §23).

## Files changed

| File | Purpose of change | Plan step | Behavior / invariant |
|---|---|---|---|
| `scripts/tests/gate-prompt-test.sh` (new) | Hermetic suite G1–G5: prompt text, `y`/`Y` acceptance, decline matrix, EOF at both reads, exact-digest assertions, approval-name mapping, edit races, styling, whitespace strictness | §17.1, §17.3, §17.5 | Criteria 1–4, 7, 10, 11; AR-001–AR-004 |
| `scripts/workflow.sh` | `gate_prompt` + `legacy_word_notice` helpers next to `hash_file`; `approve_file` captures the displayed digest before the prompt, prints the bold `Ready to approve <file>? [Y/N] ` line, accepts only `y`/`Y`, re-checks the digest after the response, and records the captured value | §17.2, §17.6 | B-3, B-5, B-7, B-8; I-2, I-4, I-6, I-7, I-8 |
| `scripts/change-workflow.sh` | Same two helpers next to `hash_file`; `human_gate` guards the preliminary `Press ENTER` read for EOF, captures one digest per gated file, derives the prompt verb from the lowercased `ACTION`, names every gated file, accepts only `y`/`Y`, re-checks all digests before writing any approval, and records the captured digests | §17.3, §17.6 | B-1, B-5, B-7, B-8; I-2, I-5, I-6, I-7, I-8; AR-001, AR-002, AR-003, AR-004 |
| `scripts/stagegate.sh` | Added `lower` next to `upper`, plus the same two helpers; `review_and_approve` lowercases `wording`, guards the preliminary read for EOF, prints the bold `Ready to <wording> <file>? [Y/N] ` line, accepts only `y`/`Y`, and records the already-validated `before` digest instead of re-hashing | §17.4, §17.6 | B-2, B-5, B-6, B-7, B-8; I-2, I-3, I-5, I-6, I-7, I-8; AR-001, AR-003 |
| `README.md` | Gate-column cells `APPROVE`/`ACKNOWLEDGE` → `Y/N` (`:167-170`, `:184-186`); `:96-97` and `:211-214` now describe the `y`/`Y` contract instead of typing an exact/requested word | §17.7 | B-9; AR-006, criterion 9 |
| `QUICK_START.md` | `:20-21` and `:71` now describe answering `y` instead of typing the requested word | §17.7 | B-9; AR-006, criterion 9 |

Files in §24 that must not change were not touched: `scripts/from-issue.sh`,
`scripts/tests/close-flow-test.sh`, `scripts/agent-kimi.sh`,
`scripts/tests/agent-kimi-test.sh`, `scripts/lib/*`, `prompts/*`, and the
`.workflow` contracts. No `close-flow-test.sh` scenario reaches a `human_gate`;
the suite passed unedited at 181 checks (plan §14 verification step).

## Pre-existing uncommitted work

At start: `ADVERSARIAL_REVIEW.md`, `CHANGE_PLAN.md`, and `UPDATED_CHANGE_PLAN.md`
had unstaged modifications. BASELINE §10 also records pending work in
`scripts/agent-kimi.sh`. None of these were modified or reverted.

## Deviations from the approved plan

| # | Deviation | Reason |
|---|---|---|
| D-1 | G2 and G3 run the gate functions lifted verbatim out of the drivers by `awk`, rather than driving `change-workflow.sh`/`stagegate.sh` to a live gate | Neither driver exposes a source-only test hook (only `from-issue.sh` does), and reaching a gate needs the lock, origin binding, and agent CLIs. Adding a hook would widen the change surface past §4/§23. The extraction is asserted non-empty, per-function present, and `bash -n`-clean, so a silent extraction failure aborts the suite instead of passing vacuously. Each harness call uses the exact argument list of a real call site. |
| D-2 | The G2/G3 harness replaces `hash_file` with a fault-injection wrapper (`MUTATE_AFTER_HASH_CALL=N`) that delegates to the real `shasum` and appends to the gated file immediately after the Nth digest is computed | Plan §13 asks for a "synchronized edit-race test" for G3. The response→recording window in `stagegate.sh` is not reachable by wall-clock timing. The wrapper returns the true digest of the bytes present at each call; it injects a mutation, it does not weaken an assertion. `workflow.sh` (G1) is raced through a real FIFO instead, since it runs as an unmodified script. |
| D-3 | `scripts/README.md` was not edited, although the §4 pre-implementation grep hit `:78` ("prompts for the exact word `RUN`") | That line documents the `from-issue.sh` `RUN` gate, which acceptance criterion 5 and I-1a explicitly preserve. It is not a stale gate instruction; rewriting it would make the documentation wrong. Acceptance criterion 9's literal `exact word` grep therefore still matches `scripts/README.md:78`. Flagged for the final audit. |
| D-4 | `lower()` was added to `scripts/stagegate.sh` as a named helper | Plan §1 specifies lowercasing via `tr`. A helper next to the existing `upper()` matches the file's idiom; `upper()` is retained and still used by `stage_setting` and `legacy_word_notice`. Behavior is as planned. |
| D-5 | `legacy_word_notice` matches `APPROVE`/`ACKNOWLEDGE` case-insensitively | A wrapper piping `approve` gets the same guidance. Strict superset of the AR-005 disposition; all such inputs still decline. |
| D-6 | The preliminary `Press ENTER` reads keep `read -r -p` rather than moving to `printf` | §4 required only the EOF guard there; §19's `printf` row covers the Y/N prompt, which is what the tests inspect. Smaller change surface. In `change-workflow.sh` the two prompt strings now go through one `prompt` variable so the EOF guard is written once. |
| D-7 | `human_gate` verifies every gated file's digest before writing any approval file | Not spelled out in §4, which describes a per-file compare. Writing approvals only after all files validate prevents a partially-approved multi-file gate. Strictly stronger than planned; no planned behavior is relaxed. |

No planned step was cut. §30's cut list was not needed: G4's PTY capture ran on
this host, so nothing was recorded NOT RUN.

## Unresolved concerns

- D-3 leaves acceptance criterion 9's literal grep matching
  `scripts/README.md:78`. The gate documentation is correct; the criterion's
  wording does not distinguish the preserved `RUN` gate from the converted
  approval gates. This needs a human or final-audit ruling, not a code change.
- R-8 stands as documented: an external wrapper that piped `APPROVE` and checks
  only the exit status still sees `0` from the two drivers on decline. The new
  decline message makes the break visible in output only.
- The manual checks M-1…M-8 (plan §15) are not covered here; they belong to
  `VERIFICATION_REPORT.md`.
