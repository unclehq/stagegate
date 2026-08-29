# Change Plan

Omitted sections: none

Scope note: item **A** (opus vs. kimi) is UNRESOLVED in CHANGE_SPEC.md §4/§14
and no model-default line is planned or edited here. Items **B**, **C**, **D**
are implemented; **E** is verification-only. Behavior/invariant IDs are
CHANGE_SPEC.md's (BEH-A…E, INV-1…5); baseline IDs are BASELINE_REPORT.md's
(B-1…B-9, I-1…I-5).

Baseline correction: BASELINE_REPORT.md §6/§12 lists `scripts/workflow.sh` as a
`.workflow/state` consumer. It is not — it touches only
`.workflow/approvals/*.sha256` (`scripts/workflow.sh:22,48,72`) and contains no
reference to the state file. It is therefore out of the change surface (§5).

## 1. Selected technical approach

Three shared-library extractions plus one new driver code path.

| Item | Approach |
|---|---|
| B | New `scripts/lib/state.sh`: `state_read`/`state_write`/`state_issue`. Writer emits `<issue>:<STAGE>` when an issue number is resolvable, bare `<STAGE>` otherwise. Reader strips a leading `^[0-9][0-9]*:` and returns the bare stage token, so every existing comparison (`== "COMPLETE"`, the `case "$state"` dispatch) keeps working unchanged. Sourced by `change-workflow.sh`, `stagegate.sh`, `from-issue.sh`. |
| C | Message-only edit in `from-issue.sh:check_origin_or_refuse`. No control-flow change: still refuses, still exits 1, still leaves state untouched. Adds a line naming the exact manual command. |
| D | New `scripts/lib/issue-close.sh` holding the I-3/INV-3 triple check (run id, origin binding, `FINAL_AUDIT.md` hash) as one function taking explicit arguments. `change-workflow.sh`'s `COMPLETE` branch calls it; `from-issue.sh:close_issue_if_ready` becomes a thin wrapper over the same function, preserving its printed strings verbatim. A close writes `.workflow/issue-closed`; the `from-issue.sh` wrapper sees that marker and skips a second close. |
| E | No code change. Confirmed by re-running the existing lock cases. |

Issue-number source for B's writer, in order: `$STAGEGATE_ORIGIN_ISSUE`, then
field 2 of `.workflow/origin`, then empty. `.workflow/state` is never read as an
issue identity — INV-1 and INV-3 continue to read `.workflow/origin` only.

D fires only when **this process** wrote the verdict record (in-process flag set
in the `FINAL_AUDIT` branch) *and* the full triple check passes. That is
strictly stronger than the `from-issue.sh` gate, satisfying CHANGE_SPEC §11.

## 2. Alternative approaches considered

| # | Alternative | Rejected because |
|---|---|---|
| A1 | B: always prefix, using `-:STAGE` when no issue is known | Breaks `README.md:282` / `QUICK_START.md:92` ("write the stage name into `.workflow/state`") and every bare-token fixture, for no gain. |
| A2 | B: keep state bare, expose the issue number in a new `.workflow/state-issue` file | Does not satisfy CR Motivation-B's literal "prepend the issue number before the state". |
| A3 | B: prefix, with each of the three scripts parsing it inline | Three copies of one grammar across two drivers and the seeder; guaranteed drift. `scripts/lib/audit-verdict.sh` is the established precedent for shared parsing. |
| A4 | B: strict reader (reject a bare token) | Turns every existing `.workflow/state`, doc instruction, and test fixture into a hard failure with no migration value. |
| A5 | D: duplicate the ~45-line close gate inside `change-workflow.sh` | Two copies of a security-relevant check drift; CHANGE_SPEC §11 explicitly warns against a second, looser gate. Retained as the §21 scope cut. |
| A6 | D: close on entering `COMPLETE` from any path, gated only by the record | A run resumed at `COMPLETE` with `STAGEGATE_RUN_ID` unset matches the recorded `-` run id and would close on state alone. The in-process flag removes that ambiguity. |
| A7 | D: have the driver `exit 1` when `gh issue close` fails | The change itself completed; failing the run would strand `COMPLETE` state behind a network error. Warn and exit 0 instead (`from-issue.sh`'s existing `exit 1` on its own close failure is preserved for the wrapper path). |
| A8 | D: drop `from-issue.sh`'s post-run close entirely | Removes the fallback for the case the driver cannot close (no `gh`, unauthenticated). CHANGE_SPEC §4-D keeps it as defensive. |

## 3. Why the selected approach is preferred

- Tolerant reader + conditional writer makes B a **forward-only, no-migration**
  format change: old bare state files, hand-written state, and the existing
  `printf 'IMPLEMENT\n' > .workflow/state` fixtures all keep working.
- Putting the stage grammar in one file means the `!= "COMPLETE"` comparisons in
  `change-workflow.sh:201` and `from-issue.sh:42` cannot silently diverge — the
  single highest-risk consequence of B (§22 R-1).
- One shared close gate keeps INV-3 enforced by exactly one piece of code
  regardless of entry point, which is the invariant CHANGE_SPEC §11 protects.
- C changes text only, so INV-5 cannot regress.

## 4. Exact components to modify

| Component | Edit |
|---|---|
| `scripts/lib/state.sh` (new) | `state_read <file>` (strip prefix, default arg for the empty case), `state_write <file> <stage> <issue>`, `state_issue <file>`. bash 3.2-compatible; no `${var^^}`, no associative arrays. |
| `scripts/lib/issue-close.sh` (new) | `issue_close_if_ready <run_id> <owner/repo> <issue> <verdict_file> <origin_file> <audit_file> <marker_file> <allow_close>`. Prints the existing reason strings verbatim; returns 0 closed, 1 skipped, 2 close failed. Writes the marker on a successful close. |
| `scripts/change-workflow.sh:121` | Source `lib/state.sh` and `lib/issue-close.sh` next to the existing `lib/audit-verdict.sh` source. |
| `scripts/change-workflow.sh:130-140` | `set_state`/`get_state` delegate to `state_write`/`state_read`; resolve the issue number from `STAGEGATE_ORIGIN_ISSUE` or `$ORIGIN_FILE`. |
| `scripts/change-workflow.sh:759-779` (`FINAL_AUDIT`) | Set the in-process `VERDICT_WRITTEN_THIS_RUN=1` flag after the verdict record is written. |
| `scripts/change-workflow.sh:781-799` (`COMPLETE`) | Before `exit 0`, when the flag is set, call `issue_close_if_ready` with the origin file's repo/issue. Skip silently when `.workflow/origin` is absent. |
| `scripts/change-workflow.sh` header | Add `WORKFLOW_CLOSE_ISSUE` (default `1`) — §15. |
| `scripts/stagegate.sh:127-137` | Same `state_write`/`state_read` delegation, sourcing `lib/state.sh`. In practice the prefix is empty (no origin binding on this driver), so on-disk output is unchanged. |
| `scripts/from-issue.sh:22-26,39-43` | `workflow_state` returns the bare stage via `state_read`; `run_in_flight` compares that. Fixes `42:COMPLETE` being read as in-flight. |
| `scripts/from-issue.sh:58-66` | C: add the manual-clear guidance line(s). |
| `scripts/from-issue.sh:132-211` | Reduce to a wrapper: marker check first, `USED_GH` guard, then `issue_close_if_ready`; keep `exit 1` on close failure. |
| `scripts/tests/close-flow-test.sh:90-92` | `new_case` copies `lib/state.sh` and `lib/issue-close.sh` into the scratch repo. |
| `scripts/tests/close-flow-test.sh:114-137` | Driver stub gains `FAKE_DRIVER_CLOSED_MARKER` to exercise the no-double-close path. |
| `scripts/tests/close-flow-test.sh:174-178` | `run_driver` passes `GH_LOG_FILE` and sanitizes ambient `STAGEGATE_ORIGIN_REPO`/`STAGEGATE_ORIGIN_ISSUE`/`STAGEGATE_RUN_ID` (`env -u`). See §22 R-4. |
| `scripts/tests/close-flow-test.sh` (new cases) | §16 table. |
| `README.md:273,282` | State-file line documents the `<issue>:<STAGE>` form and that a bare stage is still accepted; note that the driver now closes the issue itself. |
| `scripts/README.md:100-112` | Add `.workflow/issue-closed` to the file table; document driver-side closing and the C guidance message. |
| `QUICK_START.md:92` | Left as-is (bare token remains valid for `stagegate.sh`); verified, not edited. |

## 5. Components explicitly not to modify

`scripts/workflow.sh` (touches approvals only — see the baseline correction),
`scripts/lib/audit-verdict.sh`, `scripts/codex-review-plan.sh`,
`scripts/codex-create-checklist.sh`, `prompts/**`, every model/effort/turn/tool
default in `change-workflow.sh:57-79` and `stagegate.sh:59-60,83-97` (item A is
UNRESOLVED), `AGENT_CMD`/`REVIEWER_CMD` defaults, the cost ledger, the lock
implementation (`change-workflow.sh:142-183`), `origin_preflight`
(`:191-218`), `verify_approval`, `CHANGE_REQUEST.md`, and all reviewer-owned
artifacts (`ADVERSARIAL_REVIEW.md`, `MANUAL_CHECKLIST.md`, `FINAL_AUDIT.md`).

## 6. Data-flow changes

- **B**: stage token → `state_write` → `<issue>:<STAGE>` on disk →
  `state_read` → bare stage token at every reader. Issue number flows
  *in* from `STAGEGATE_ORIGIN_ISSUE`/`.workflow/origin` and flows *out* only to
  human-readable output; no decision reads it.
- **D**: `.workflow/audit-verdict` + `.workflow/origin` + `FINAL_AUDIT.md` →
  `issue_close_if_ready` → `gh issue close` → `.workflow/issue-closed` →
  read by `from-issue.sh` to suppress a duplicate close. Previously this chain
  existed only inside `from-issue.sh`.

## 7. State-transition changes

No state is added, removed, or reordered. The `ANALYZE → … → COMPLETE`
sequence is byte-for-byte the same set of tokens. The only transition-level
change is a side effect on entering `COMPLETE`: a close attempt when this
process wrote the verdict. `COMPLETE` still `exit 0`s, and a failed close does
not change the state or the exit status.

## 8. Interface and API changes

| Interface | Change | Compatible? |
|---|---|---|
| `.workflow/state` contents | May now carry an `<issue>:` prefix | Readers accept both forms |
| `.workflow/issue-closed` (new) | `<run_id>TAB<owner/repo>TAB<issue>` | Additive; absence means "not closed by the driver" |
| `WORKFLOW_CLOSE_ISSUE` (new env) | `1` (default) / `0` disables D | Additive |
| `change-workflow.sh` CLI | Unchanged (no args, `-h`, `--version`) | Yes |
| `from-issue.sh` CLI | Unchanged | Yes |
| Printed output | New driver lines on close/skip; new C guidance line | Additive; no existing asserted line is reworded |

## 9. Schema or persistence changes

`.workflow/state` grammar becomes `[<digits>:]<STAGE>`; `.workflow/issue-closed`
is new. `.workflow/origin`, `.workflow/audit-verdict`, `.workflow/cost.tsv`,
`.workflow/lock/`, and `.workflow/approvals/*.sha256` are untouched.
`.gitignore:1` already ignores all of `.workflow`, so the new file needs no
gitignore edit.

## 10. Compatibility strategy

- Bare-token state files stay readable indefinitely (no dual-format *writing*,
  only tolerant reading) — satisfies CHANGE_SPEC §8's "all consumers move
  together" without a transition period.
- Every existing printed string asserted by `close-flow-test.sh` is preserved
  verbatim through the `issue-close.sh` extraction; the wrapper's `USED_GH` and
  `exit 1`-on-failure semantics are unchanged.
- `stagegate.sh` output is unchanged in practice (no issue number available).

## 11. Concurrency implications

- The driver's close runs while it still holds `.workflow/lock` (a network call
  under the mutex). Accepted deliberately: releasing the lock before the close
  would let a second run enter and mutate `FINAL_AUDIT.md`/the verdict record
  between the check and the close, which is precisely the AR-002/AR-003 race
  INV-2 exists to prevent. Bounded by `gh`'s own timeout.
- Driver close then `from-issue.sh` close is a two-actor sequence on one issue.
  The marker file makes the second a no-op. It is written only after `gh issue
  close` returns 0, so a crash between close and marker write degrades to the
  pre-change behavior (a redundant close attempt), not to a wrong close.
- `.workflow/state` writes remain single-writer under INV-2; B adds no new
  writer.

## 12. Error and recovery behavior

| Condition | Behavior |
|---|---|
| `.workflow/state` unreadable/empty | Unchanged: `ANALYZE` (change) / `REQUIREMENTS` (stagegate) |
| State has an unrecognized prefix (e.g. `abc:IMPLEMENT`) | Prefix is not stripped; token falls through to the existing `Unknown workflow state` branch, exit 1, with the existing "Delete …/state to restart" hint |
| `.workflow/origin` absent at `COMPLETE` | D skipped silently, run completes, exit 0 (CHANGE_SPEC §9) |
| Verdict not READY / not this run / hash mismatch | Reason printed, no close, exit 0 |
| `gh` missing or unauthenticated in the driver | Reason printed, no close, no marker, exit 0; `from-issue.sh` fallback still applies |
| `gh issue close` fails in the driver | Warning printed, no marker, exit 0 (A7) |
| `gh issue close` fails under `from-issue.sh` | Unchanged: message + `exit 1` |
| C: issue mismatch at seed time | Unchanged refusal, exit 1, state untouched, plus the guidance line |

## 13. Migration plan

None required. Reading is backward compatible (§10) and the prefix appears on
the next `set_state` write. Operators with an in-flight bare-token state file
need to do nothing; the file self-migrates at the next stage transition if an
origin is bound.

## 14. Rollback plan

Per item, independently:

| Item | Rollback |
|---|---|
| B | `git revert` the state-format commit. Bare writing resumes immediately; any `<issue>:<STAGE>` file left on disk is then unreadable by the reverted parser, so the operator rewrites the bare token (`printf 'IMPLEMENT\n' > .workflow/state`) — documented in the commit message. No other artifact is affected. |
| C | Revert the message commit; text-only. |
| D | Set `WORKFLOW_CLOSE_ISSUE=0` for an immediate, no-deploy kill switch, or revert the commit. `from-issue.sh`'s original close path is preserved, so reverting D restores B-9 behavior exactly. |
| E | Nothing to roll back. |

Full rollback = revert the (up to four) commits in reverse order; no data
migration, no approval-hash invalidation, no external state to undo beyond an
already-closed GitHub issue, which is reopened by hand.

## 15. Feature-flag or containment strategy

`WORKFLOW_CLOSE_ISSUE` (default `1`) gates only the new driver-side close in
`COMPLETE`. Set to `0` and behavior is exactly B-9. B and C are not flagged: B
is backward compatible by construction and C is a message. No prototype is
involved, so no experiment isolation is required.

## 16. Automated-test strategy

All in `scripts/tests/close-flow-test.sh` (hermetic; stubbed `gh`, stubbed or
fake reviewer; no network).

| Case | Item | Asserts |
|---|---|---|
| `state-prefix-written` | B | After a driver run with `.workflow/origin` = `owner/repo TAB 42`, `.workflow/state` is `42:COMPLETE` |
| `state-bare-still-read` | B | Pre-set bare `FINAL_AUDIT` still dispatches and completes (no regression for legacy files) |
| `state-no-origin-stays-bare` | B | Driver run with no origin file writes a bare token |
| `state-unknown-prefix-refused` | B | `abc:IMPLEMENT` → exit 1, "Unknown workflow state" |
| `seed-gate-prefixed-complete-reseeds` | B | `42:COMPLETE` → `SEED_WRITE` (regression test, §17) |
| `seed-gate-prefixed-inflight-refuses` | B | `99:IMPLEMENT` + foreign origin → exit 1, refusal |
| `preflight-prefixed-complete-passes` | B | `42:COMPLETE` + foreign origin + `STAGEGATE_ORIGIN_*` → exit 0 |
| `seed-gate-mismatch-prints-guidance` | C | Refusal output contains the manual-clear command |
| `direct-run-closes` | D | Real driver, no `from-issue.sh`, origin present, fake reviewer READY → `gh issue close` logged, `.workflow/issue-closed` written, exit 0 |
| `direct-run-not-ready-stays-open` | D | NOT READY verdict → no close, exit 0 |
| `direct-run-no-origin-skips-close` | D | No origin file → no close, "Change workflow complete.", exit 0 |
| `direct-run-gh-unauth-skips-close` | D | `FAKE_GH_AUTH_RC=1` → no close, no marker, exit 0 |
| `direct-run-close-flag-off` | D | `WORKFLOW_CLOSE_ISSUE=0` → no close, exit 0 |
| `direct-run-close-fails-still-completes` | D | `FAKE_GH_CLOSE_RC=1` → warning, no marker, exit 0 |
| `no-double-close-after-driver` | D | Stub driver writes a matching marker → `from-issue.sh` reports it and issues no second `gh issue close` |
| `stale-marker-ignored` | D | Marker naming another run/issue → `from-issue.sh` still performs its own gated close |

`scripts/tests/audit-verdict-test.sh` is unchanged. Both suites run via
`bash scripts/tests/<name>.sh`; the pass bar is the existing 125 checks green
plus every new case green.

## 17. Regression-test strategy

The one genuine latent bug this change would introduce is B breaking the
`state != "COMPLETE"` comparisons. Written first, before the format change
(core rule 8):

- **`seed-gate-prefixed-complete-reseeds`** — writes `42:COMPLETE`, runs the
  seed gate, expects `SEED_WRITE`. **Fails** against a naive `set_state`
  prefix (the raw comparison makes `42:COMPLETE` look in-flight and the gate
  refuses); **passes** once `from-issue.sh` reads through `state_read`.
- **`preflight-prefixed-complete-passes`** — the driver-side mirror
  (`change-workflow.sh:201`), same fail-then-pass property.

Everything else is regression protection for existing behavior: the 99 existing
`close-flow-test.sh` checks must stay green across the `issue-close.sh`
extraction (message strings, `USED_GH`, exit codes), and the `lock-*` cases
carry item E.

## 18. Manual-verification strategy

Reviewer-authored `MANUAL_CHECKLIST.md` governs; the checks this plan expects to
be feasible:

| # | Check | Item |
|---|---|---|
| MV-1 | Run the driver one stage against a real bound run; `cat .workflow/state` shows `<issue>:<STAGE>` | B |
| MV-2 | Hand-write a bare stage token per `README.md:282` and re-run; the stage replays | B |
| MV-3 | `./scripts/from-issue.sh <other-issue> --change` against an in-flight foreign state; confirm refusal, exit 1, unchanged `.workflow/state`, and that the printed command is the one that actually clears it | C, INV-5 |
| MV-4 | Run `./scripts/change-workflow.sh` directly to a READY audit against a disposable test issue with `gh` authenticated; the issue is closed and `.workflow/issue-closed` exists | D |
| MV-5 | Same with `WORKFLOW_CLOSE_ISSUE=0`; the issue stays open | D |
| MV-6 | `ls .workflow/lock` after both a successful and a `Ctrl-C`'d run — absent both times | E |

Not feasible here: anything requiring a `kimi` binary (item A, no binary
available — baseline §15).

## 19. Observability changes

New lines on stdout only: the driver's close outcome or skip reason at
`COMPLETE`, and C's guidance line. `.workflow/issue-closed` is a durable record
of which run closed which issue. No new log files, no change to
`.workflow/logs/*` or the cost ledger.

## 20. Implementation sequence

1. Add `seed-gate-prefixed-complete-reseeds` and
   `preflight-prefixed-complete-passes` to `close-flow-test.sh`; teach
   `new_case` to copy `scripts/lib/*.sh`; fix `run_driver`'s env sanitizing
   (§22 R-4). Run both suites — the two new cases fail only after step 2 exists
   in naive form; record the observed baseline (125 green).
2. Add `scripts/lib/state.sh`. Wire `from-issue.sh` and
   `change-workflow.sh` readers to `state_read` first, then switch the writers
   to `state_write`. Run both suites — the two regression cases must go green.
3. Wire `stagegate.sh` to the same lib. Run both suites.
4. Add the remaining B test cases. Run both suites.
5. C: guidance message + `seed-gate-mismatch-prints-guidance`. Run both suites.
6. Extract `scripts/lib/issue-close.sh` from `from-issue.sh:132-211`; make
   `from-issue.sh` a wrapper. Run both suites — **all 99 existing checks must
   stay green with no message edits**; this is the extraction's acceptance bar.
7. Add the marker file, the `WORKFLOW_CLOSE_ISSUE` flag, the driver's
   `VERDICT_WRITTEN_THIS_RUN` flag, and the `COMPLETE`-branch close. Add the D
   test cases. Run both suites.
8. Docs: `README.md`, `scripts/README.md`. Verify `QUICK_START.md:92` still
   holds without an edit.
9. Full suite run; write `IMPLEMENTATION_NOTES.md` and `CHANGE_TEST_REPORT.md`.

Item A is not in this sequence by design.

## 21. Scope cuts under time pressure

Cut in this order:

1. `stagegate.sh` state wiring (step 3) — no issue number reaches that driver,
   so it is symmetry only. Cutting it leaves BEH-B satisfied for the
   change-workflow path and must be recorded as a deviation.
2. The `issue-close.sh` extraction (step 6) — fall back to A5: a self-contained
   close function inside `change-workflow.sh` reusing the identical triple
   check, `from-issue.sh:132-211` untouched. Costs duplication, keeps INV-3 at
   equal strength, removes all regression risk from the 99 existing checks.
3. The `WORKFLOW_CLOSE_ISSUE` flag (containment only; D is revertible without
   it).
4. `stale-marker-ignored` and `direct-run-close-fails-still-completes` test
   cases.

Never cut: the two §17 regression tests, the marker file (double-close
protection), and the docs update for B.

## 22. Risks and unresolved questions

| ID | Risk | Mitigation |
|---|---|---|
| R-1 | B breaks a `state == "COMPLETE"` comparison somewhere, silently turning a finished run into an "in-flight, foreign" one and blocking all future seeding | Single shared parser; two dedicated fail-first regression tests (§17); both comparison sites enumerated (`change-workflow.sh:201`, `from-issue.sh:42`) |
| R-2 | The `issue-close.sh` extraction reworks a message string and breaks `expect_out` assertions | Step 6 is a pure move with the suite as the gate; scope cut #2 is the escape hatch |
| R-3 | Driver close + `from-issue.sh` close both fire against a real issue | Marker file; `gh issue close` on an already-closed issue is in any case idempotent |
| R-4 | New D tests are non-deterministic when `STAGEGATE_ORIGIN_*`/`STAGEGATE_RUN_ID` leak from an ambient stagegate session (baseline §10) — the direct-run cases require them absent | `run_driver` sanitizes them with `env -u`. **This is a test-isolation fix outside the CR's literal scope (core rule 5); it is necessary for the new tests to be meaningful and is flagged here for explicit approval.** |
| R-5 | The driver holds the lock across a network call | §11; bounded, and the alternative reopens AR-002/AR-003 |
| R-6 | A close that succeeds while the marker write fails (disk full, signal) | Degrades to today's behavior — a second, gated, idempotent close attempt |
| R-7 | UNRESOLVED — item A (opus vs. kimi) | No model line is edited. Needs the human's answer before any follow-on change; `kimi` flag compatibility is separately unverified (no binary available) |
| R-8 | UNRESOLVED — item E's "`.workflow/lock/lock`" names nothing that exists | Treated as satisfied by B-8 and verified by MV-6; if the human meant a different path, that is a new request |

## Change-impact table

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/lib/state.sh` (new) | Stage-token grammar: write with optional `<issue>:` prefix, read tolerantly | B, single parser (§3) | Low (new file) | `state-*` cases; exercised indirectly by all 125 existing checks |
| `scripts/lib/issue-close.sh` (new) | Extracted INV-3 triple check + `gh` close + marker write | D without a second, looser gate (CHANGE_SPEC §11) | Medium — carries 12 existing asserted message strings | All existing verdict/close cases plus the `direct-run-*` cases |
| `scripts/change-workflow.sh` state helpers (`:130-140`) | Delegate to the lib; resolve issue from env/origin | B | Medium — every stage read/write flows through it | `state-*`, `preflight-*`, and every end-to-end driver case |
| `scripts/change-workflow.sh` `FINAL_AUDIT`/`COMPLETE` (`:759-799`) | In-process verdict flag; gated close before `exit 0` | D | Medium — new side effect on the terminal state | `direct-run-*`, `verdict-record-written`, `stale-audit-rejected` |
| `scripts/change-workflow.sh` header | `WORKFLOW_CLOSE_ISSUE` default `1` | Containment (§15) | Low | `direct-run-close-flag-off` |
| `scripts/stagegate.sh:127-137` | Same lib delegation; prefix empty in practice | B symmetry (BEH-B says "either driver") | Low — no automated suite covers this driver | Manual MV-1/MV-2 reasoning only; §21 cut #1 |
| `scripts/from-issue.sh:22-43` | Read state through the lib | B — prevents R-1 | High if omitted, low as planned | §17 regression cases |
| `scripts/from-issue.sh:58-66` | C guidance message | CHANGE_SPEC §4-C | Low (text only) | `seed-gate-mismatch-prints-guidance` + existing refusal cases |
| `scripts/from-issue.sh:132-211` | Becomes a wrapper: marker check, `USED_GH` guard, shared gate | D, no duplicate gate | Medium — see R-2 | All 12 existing close-decision cases must stay green |
| `scripts/tests/close-flow-test.sh` | Copy new libs, `GH_LOG_FILE` for `run_driver`, env sanitizing, ~16 new cases | Coverage for B/C/D; R-4 | Test-only | Self |
| `README.md`, `scripts/README.md` | Document the state grammar, driver-side close, marker file, flag | CHANGE_SPEC §8 anti-drift | None (docs) | Reviewer read |
| Model/effort defaults | **No change** | Item A UNRESOLVED | N/A | N/A |

## Traceability

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| CR Motivation-A (opus/kimi) | BEH-A (EXPERIMENTAL, UNRESOLVED) | — | none (deliberately) | none | none — blocked on the human (R-7) |
| CR Motivation-B (issue number in state) | BEH-B (MODIFY) | INV-1 (not weakened; state is never an identity source) | `lib/state.sh`, `change-workflow.sh:130-140`, `stagegate.sh:127-137`, `from-issue.sh:22-43` | `state-prefix-written`, `state-bare-still-read`, `state-no-origin-stays-bare`, `state-unknown-prefix-refused`, `seed-gate-prefixed-*`, `preflight-prefixed-complete-passes` | MV-1, MV-2 |
| CR Motivation-C (zero state on mismatch) | BEH-C (PRESERVE + message) | INV-5 (EXISTING, NOT RELAXED), INV-1 | `from-issue.sh:58-66` | `seed-gate-mismatch-prints-guidance`, `seed-gate-foreign-origin`, `seed-gate-unowned-state`, `preflight-origin-mismatch`, `preflight-origin-absent` | MV-3 |
| CR Motivation-D (close on completion) | BEH-D (MODIFY) | INV-3 (STRENGTHENED) | `lib/issue-close.sh`, `change-workflow.sh:759-799`, `from-issue.sh:132-211` | `direct-run-closes`, `direct-run-not-ready-stays-open`, `direct-run-no-origin-skips-close`, `direct-run-gh-unauth-skips-close`, `direct-run-close-flag-off`, `direct-run-close-fails-still-completes`, `no-double-close-after-driver`, `stale-marker-ignored`, all existing close-decision cases | MV-4, MV-5 |
| CR Motivation-E (remove lock) | BEH-E (PRESERVE) | INV-2 | none | `lock-held-by-live-pid`, `lock-stale-pid-cleared` | MV-6 |
| CHANGE_SPEC §8 (docs move with the change) | — | — | `README.md`, `scripts/README.md` | none | Reviewer read |
