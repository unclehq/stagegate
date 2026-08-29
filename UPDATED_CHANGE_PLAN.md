# Updated Change Plan

Omitted sections: none

This document supersedes CHANGE_PLAN.md only where noted below. CHANGE_PLAN.md
is hash-approved and immutable; sections not listed as changed apply as
written there. IDs: BEH-A…E, INV-1…5 are CHANGE_SPEC.md's; B-1…B-9, I-1…I-5 are
BASELINE_REPORT.md's; AR-001…009 are ADVERSARIAL_REVIEW.md's.

## Disposition of adversarial findings

| Finding | Disposition | Reason | Exact plan change |
|---|---|---|---|
| AR-001 (Critical, blocks) — stale origin closes wrong issue on a fresh direct run | Accepted | Real gap: `origin_preflight` (`change-workflow.sh:191-198`) short-circuits when `STAGEGATE_ORIGIN_*` is unset, so a fully direct run never validates a leftover `.workflow/origin` against anything before using it to close. Item B's state prefix cannot serve as the missing check either — it is itself derived from the same stale origin, so it corroborates nothing. | New precondition in `issue_close_if_ready`: closing is eligible only if (a) `.workflow/state` was already prefix-bound (non-empty, carrying an issue prefix) at this process's start — i.e. a genuinely resumed run — **or** (b) `STAGEGATE_ORIGIN_ISSUE`/`STAGEGATE_ORIGIN_REPO` were explicitly set in this process's environment, proving deliberate operator binding for *this* invocation. A fresh run (no prior state) relying solely on a stray on-disk `.workflow/origin` file satisfies neither and is refused with a printed reason, no close, no marker. This does touch `origin_preflight`'s neighborhood, a deviation from CHANGE_PLAN §5 — recorded here per core rule 9. |
| AR-002 (High, blocks) — one transient `gh` failure permanently strands the issue open | Accepted | A7's original design (warn, exit 0, don't strand `COMPLETE`) is right, but nothing lets a later rerun retry, since `VERDICT_WRITTEN_THIS_RUN` is process-local and a rerun starting at `COMPLETE` never re-enters `FINAL_AUDIT`. | Add a second, narrower trigger in the `COMPLETE` branch: if the marker file is absent and the on-disk verdict record's run id is a **concrete, non-`-` value** equal to `STAGEGATE_RUN_ID`, attempt `issue_close_if_ready` again even without the in-process flag. Excluding the `-` sentinel preserves A6's original reasoning (a `-` recorded id must never be treated as matching an unset `STAGEGATE_RUN_ID`), so retry is only enabled for runs whose identity is unambiguous. |
| AR-003 (High, blocks) — driver-side close bypasses the curl-fallback safeguard | Accepted | `USED_GH` (`from-issue.sh:308-319`) is local and never reaches the driver, so `change-workflow.sh`'s close gate has no way to know the origin issue was ever viewed with authenticated `gh` rather than an unauthenticated `curl` fallback — B-9's existing promise ("curl-fetched origin never authorizes a write") is not carried into the new driver-side path. | Extend `.workflow/origin`'s format with a third, space-delimited field written only by `write_origin`: `gh` when the issue view used authenticated `gh`, `curl` when it used the fallback. `issue_close_if_ready` refuses to close when this field reads `curl`. A two-field legacy origin file (no third field) is treated as `curl` (fail closed), never as `gh` — this is the one non-additive-safe corner of B, and is deliberately conservative. |
| AR-004 (High, blocks) — a state-prefix/origin-issue disagreement is silently ignored | Accepted | CHANGE_SPEC §4-B's "informational only" design for the state prefix is sound for the *common* case, but it means a corrupted or hand-edited state file (`99:IMPLEMENT` next to an origin naming `42`) is invisibly accepted rather than flagged, since nothing ever compares the two. | Add a comparison at both `origin_preflight` and the seed gate (`from-issue.sh:22-43`): when `state_read`'s stripped prefix is non-empty and differs from `.workflow/origin`'s issue field, treat it as corruption — refuse, exit 1, state untouched, distinct message from the ordinary foreign-origin refusal. This is a second, disclosed deviation from CHANGE_PLAN §5's "not to modify `origin_preflight`". |
| AR-005 (High, blocks) — item A ships unresolved and untested | Partially accepted | Not a new finding: CHANGE_SPEC §4-A, §14-1/2, and CHANGE_PLAN §5/§21/§22 R-7 already disclose that A is blocked on the human and is deliberately out of this delivery's scope, per CHANGE_SPEC §1's explicit design that A/B/C/D/E are independently approvable. It is not a defect in the B/C/D/E plan. | No code or scope change. Add one explicit line to the completion report (see Exact acceptance criteria, below) stating this delivery is partial and CR Motivation-A remains open, so completion of B/C/D/E is never read as closing the whole CR. |
| AR-006 (High, blocks) — refusal substituted for the CR's literal "zero state" ask without re-litigating it here | Rejected | The substitution was already made and reasoned in CHANGE_SPEC §4-C/§7/§14-3 (auto-zero reopens exactly the class of identity-trust failure AR-001 itself warns about) at an earlier, already-passed human gate. CHANGE_PLAN's job is to implement CHANGE_SPEC, not reopen it; nothing in AR-006 presents new evidence that changes the INV-5 analysis — if anything AR-001 reinforces it. | None. Reopening this requires a CHANGE_SPEC revision and a fresh approval, out of this document's authority. |
| AR-007 (High, blocks) — `stagegate.sh` is unlocked and can race `change-workflow.sh` on shared `.workflow/state`/`FINAL_AUDIT.md` | Deferred | Real, but pre-existing: both drivers already write these files today with no shared mutex; item D's new close only runs under `change-workflow.sh`'s own existing lock and neither creates nor worsens the cross-driver race. Making the lock (or artifact namespace) span both drivers is an architecture change beyond this CR's frozen scope. | No code change to fix the race itself. Per the disposition of AR-009 (below), the one piece of this plan that *increased* stagegate's coupling to the shared parser — item B's `stagegate.sh` wiring (CHANGE_PLAN §4 step 3) — is dropped outright rather than merely listed as a time-pressure cut, so this change does not add new incentive to treat the two drivers as more unified than the lock actually makes them. Recommend a follow-up CR for cross-driver mutual exclusion. |
| AR-008 (Medium, non-blocking) — unbounded `gh issue close` can hold the lock indefinitely | Accepted | CHANGE_PLAN §11's "bounded by `gh`'s own timeout" is an assumption, not a guarantee. | Wrap the close call with a portable deadline (`timeout 30 gh issue close …` when `timeout`/`gtimeout` is available, otherwise unchanged behavior — noted as a known gap on macOS without coreutils). A timeout is treated identically to any other close failure: warn, no marker, exit 0 (or eligible for the AR-002 retry). |
| AR-009 (Medium, non-blocking) — `stagegate.sh` wiring is unneeded, uncovered refactoring | Accepted | No issue identity exists on that driver in practice (CHANGE_PLAN §4 already says the prefix is empty there), no automated suite exercises it, and §21 already flagged it as the first thing to cut. Combined with AR-007, keeping the two drivers' coupling to a shared parser minimal is the safer default. | Drop `scripts/stagegate.sh:127-137` wiring entirely (not merely as a time-pressure cut). `stagegate.sh` moves from CHANGE_PLAN §4 into the not-modified list. BEH-B is satisfied for the change-workflow path only; this is a permanent, disclosed scope reduction, not a resource-driven fallback. |

## 1. Selected technical approach

Unchanged from CHANGE_PLAN.md § 1 for items B (state prefix format/parsing),
C, and E. Item D's approach is extended, not replaced:

D now additionally requires, before any close attempt:

- **Origin-freshness guard (AR-001):** resumed-run state prefix present, or
  explicit `STAGEGATE_ORIGIN_*` env for this invocation.
- **Fetch-provenance guard (AR-003):** `.workflow/origin`'s third field must
  read `gh`, never `curl` or absent.
- **Retry-on-rerun (AR-002):** a `COMPLETE`-state rerun with no marker and a
  concrete (non-`-`) matching run id gets a second close attempt.
- **Timeout (AR-008):** the `gh issue close` call itself runs under a
  best-effort deadline.

Item B is extended by one corruption check (AR-004): a non-empty state prefix
that disagrees with `.workflow/origin`'s issue is refused, not silently
overridden by origin.

Item B's `stagegate.sh` wiring (CHANGE_PLAN §4 step 3) is dropped (AR-007/
AR-009 disposition, above).

## 2. Alternative approaches considered

Unchanged from CHANGE_PLAN.md § 2, plus:

| # | Alternative | Rejected because |
|---|---|---|
| A9 | AR-001: validate origin freshness by comparing file mtime to process start | Racy and meaningless across machine clock skew, NFS mounts, and normal same-second operation; gives false confidence. |
| A10 | AR-001: require a network round-trip to `gh` confirming the origin issue still references the current `CHANGE_REQUEST.md` content | Correct in principle but out of scope: turns a local safety check into a mandatory network dependency for every close decision, and there is no defined mapping from issue body to `CHANGE_REQUEST.md` content to compare against. |
| A11 | AR-003: trust `gh auth status` at close time as sufficient provenance | This is exactly today's bypass — authentication *now* says nothing about how the *origin binding* was originally fetched; the whole point of `USED_GH` is to record history, not current capability. |
| A12 | AR-002: unconditionally retry close on every rerun that reaches `COMPLETE` | Reintroduces A6's exact ambiguity (a recorded `-` run id spuriously matching an unset `STAGEGATE_RUN_ID`); the concrete-id restriction avoids it without giving up retry. |

## 3. Why the selected approach is preferred

Unchanged from CHANGE_PLAN.md § 3, plus: each new guard is additive and
fail-closed — a run that cannot prove its origin/fetch/identity provenance
simply does not close the issue, it never mis-closes one. That preserves the
same design property CHANGE_PLAN §3 already claims for B and D: exactly one
piece of code enforces INV-3, now strengthened with the AR-001/003/004
preconditions folded into that single gate rather than scattered.

## 4. Exact components to modify

Unchanged from CHANGE_PLAN.md § 4 for the `state.sh`, `change-workflow.sh`
sourcing/state-helper, `from-issue.sh` (state read, C guidance, wrapper), and
test-file rows. Changed/added rows:

| Component | Edit |
|---|---|
| `scripts/change-workflow.sh:191-218` (`origin_preflight`) | **Now modified** (was "not to modify" — AR-001/AR-004 deviation). Add: (1) refuse when a non-empty state prefix disagrees with `.workflow/origin`'s issue (AR-004); (2) compute and pass forward the origin-freshness signal (resumed-with-prefix vs. explicit `STAGEGATE_ORIGIN_*`) used by the close gate (AR-001). |
| `scripts/from-issue.sh:22-43` | Same AR-004 prefix/origin disagreement check added to the seed gate's path (mirrors the driver-side check; both comparison sites enumerated per the same discipline as CHANGE_PLAN §3's B-format concern). |
| `scripts/from-issue.sh` `write_origin` | Writes the third, space-delimited fetch-provenance field (`gh`/`curl`) alongside repo/issue (AR-003). Two-field origin files remain readable (treated as `curl`, fail-closed). |
| `scripts/lib/issue-close.sh` (`issue_close_if_ready`) | Gains three new required inputs: origin-freshness signal (AR-001), fetch-provenance field (AR-003), and "already-`COMPLETE`-with-concrete-run-id" retry signal (AR-002). Wraps the `gh issue close` call in a portable timeout (AR-008). Reasons for refusal on any new guard are printed strings, added to (not replacing) the existing reason set — no existing string changes. |
| `scripts/change-workflow.sh:759-799` (`FINAL_AUDIT`/`COMPLETE`) | Compute and hold the AR-001 freshness signal at `ANALYZE` entry (before any state mutation), not at `COMPLETE`, so a resumed-vs-fresh determination reflects the run's actual start state. Add the AR-002 retry branch alongside the existing flag-gated branch. |
| `scripts/tests/close-flow-test.sh` (new cases) | §16 table, below. |

Dropped from CHANGE_PLAN §4: `scripts/stagegate.sh:127-137` state-lib wiring
(AR-007/AR-009).

## 5. Components explicitly not to modify

Unchanged from CHANGE_PLAN.md § 5, **except**: `origin_preflight`
(`change-workflow.sh:191-218`) is removed from this list (now modified, per
§4 above — recorded here as the required core-rule-9 deviation). `verify_approval`
and the lock implementation (`:142-183`) remain untouched.
`scripts/stagegate.sh` is added to this list in full (its state-format wiring
is dropped, not merely deferred — AR-007/AR-009).

## 6. Data-flow changes

Unchanged from CHANGE_PLAN.md § 6 for B's stage-token flow (bare-token
reading/writing) and D's original close chain. Added:

- **AR-001**: run-start state (empty vs. prefixed) and `STAGEGATE_ORIGIN_*`
  env presence → freshness signal → `issue_close_if_ready`'s new precondition.
  Flows in only; never written back to disk.
- **AR-003**: `write_origin`'s fetch method → third `.workflow/origin` field
  → `issue_close_if_ready`'s provenance precondition. A two-field legacy file
  flows to "fail closed" without erroring.
- **AR-002**: on-disk verdict record's run id + marker absence, read fresh at
  every `COMPLETE` entry (not only when the in-process flag is set) →
  eligibility for a second close attempt.
- **AR-004**: state prefix + origin issue, compared at `origin_preflight` and
  the seed gate → refuse-on-disagreement, no data written.

## 7. State-transition changes

Unchanged from CHANGE_PLAN.md § 7: no stage is added, removed, or reordered.
Additional note: a rerun that lands on `COMPLETE` may now attempt a close
side effect it did not attempt on a prior invocation (AR-002); this remains a
side effect only, `COMPLETE` still `exit 0`s regardless of outcome.

## 8. Interface and API changes

Unchanged from CHANGE_PLAN.md § 8, plus:

| Interface | Change | Compatible? |
|---|---|---|
| `.workflow/origin` contents | Gains a third, space-delimited fetch-provenance field (`gh`/`curl`) | Additive for readers that only use fields 1–2; the close gate treats a missing field 3 as `curl` (fail-closed), so old two-field files never gain new close authority they didn't already have under B-9 |

## 9. Schema or persistence changes

Unchanged from CHANGE_PLAN.md § 9, plus: `.workflow/origin` grammar becomes
`<owner/repo> TAB <issue> [TAB <gh|curl>]`; the third field is optional on
read, always written going forward by `write_origin`.

## 10. Compatibility strategy

Unchanged from CHANGE_PLAN.md § 10, plus: a pre-existing two-field
`.workflow/origin` file is read successfully and simply cannot satisfy the
AR-003 provenance guard until the next `write_origin` refreshes it — this is
intentionally conservative (fail closed), not a functional regression, since
B-9's `from-issue.sh`-only close path already required its own `USED_GH`
check every time and is unaffected.

## 11. Concurrency implications

Unchanged from CHANGE_PLAN.md § 11's first and third bullets. Second bullet
extended: the close call now runs under a bounded timeout (AR-008), reducing
(not eliminating) the indefinite-hold risk while still occurring under the
lock, for the reasons CHANGE_PLAN §11 already gives (releasing the lock first
reopens the AR-002/AR-003-class race the mutex exists to prevent — note this
reuses CHANGE_PLAN's own numbering for a different AR-002/003 than this
review's; see CHANGE_PLAN §11 verbatim). AR-007's cross-driver race
(`stagegate.sh` vs. `change-workflow.sh`) is explicitly out of scope for this
change (disposition, above) and is not mitigated here.

## 12. Error and recovery behavior

Unchanged from CHANGE_PLAN.md § 12, plus:

| Condition | Behavior |
|---|---|
| Fresh run (no prior state) with a leftover `.workflow/origin` and no explicit `STAGEGATE_ORIGIN_*` | D skipped, reason printed, exit 0 (AR-001) |
| `.workflow/origin`'s fetch-provenance field is `curl` or absent | D skipped, reason printed, exit 0 (AR-003) |
| State prefix and `.workflow/origin` issue disagree | Refuse, exit 1, state untouched, distinct message (AR-004) |
| Rerun lands on `COMPLETE`, no marker, verdict run id concrete and matching | Second close attempt; same outcomes as a first attempt (AR-002) |
| Rerun lands on `COMPLETE`, no marker, verdict run id is `-` | No retry (ambiguous sentinel, A6/A12 reasoning), stays open until a manual close |
| `gh issue close` exceeds the timeout | Treated as a close failure: warning, no marker, exit 0, eligible for later AR-002 retry (AR-008) |

## 13. Migration plan

Unchanged from CHANGE_PLAN.md § 13. The origin third field self-populates on
the next `write_origin` call; no operator action required, and old files
degrade only to "cannot yet satisfy the new provenance guard," not to an
error.

## 14. Rollback plan

Unchanged from CHANGE_PLAN.md § 14. The AR-001/002/003/004/008 guards live
entirely inside the same commits as B and D respectively; reverting those
commits removes the guards along with the features they gate, with no
partial state.

## 15. Feature-flag or containment strategy

Unchanged from CHANGE_PLAN.md § 15. `WORKFLOW_CLOSE_ISSUE=0` continues to
disable all of D, including every new guard, as a single kill switch.

## 16. Automated-test strategy

Unchanged from CHANGE_PLAN.md § 16's existing 16 rows (with `stagegate.sh`
no longer a relevant edit, per §4/§5 above, `state-*` cases still cover the
change-workflow/from-issue.sh path). Added:

| Case | Item | Asserts |
|---|---|---|
| `direct-run-stale-origin-fresh-state-skips-close` | AR-001 | Empty state, leftover origin for a different issue, no explicit `STAGEGATE_ORIGIN_*` → no close, reason printed, exit 0 |
| `direct-run-explicit-origin-env-closes` | AR-001 | Empty state, `STAGEGATE_ORIGIN_ISSUE`/`_REPO` explicitly set for this invocation → close proceeds as before |
| `direct-run-close-retries-on-rerun` | AR-002 | First run: `FAKE_GH_CLOSE_RC=1` → no close. Second run (rerun at `COMPLETE`, same concrete run id, marker absent, healthy `gh`) → exactly one successful close |
| `direct-run-stale-sentinel-run-id-no-retry` | AR-002 | Verdict record's run id is `-`; rerun at `COMPLETE` with `STAGEGATE_RUN_ID` unset → no retry attempt |
| `curl-fallback-driver-side-skips-close` | AR-003 | `.workflow/origin`'s third field is `curl` → no close, no marker, exit 0, even with healthy authenticated `gh` at close time |
| `legacy-two-field-origin-skips-close` | AR-003 | Pre-change two-field origin file (no third field) → treated as `curl`, no close |
| `state-origin-issue-mismatch-refused` | AR-004 | State `99:IMPLEMENT`, origin issue `42` → refuse, exit 1, unchanged state, distinct message, at both the seed gate and `origin_preflight` |
| `direct-run-close-timeout-treated-as-failure` | AR-008 | `gh issue close` stub blocks past the deadline → warning, no marker, exit 0, lock released |

The pass bar is the CHANGE_PLAN §16 bar (125 existing + its ~16 new cases)
plus all 8 rows above green.

## 17. Regression-test strategy

Unchanged from CHANGE_PLAN.md § 17. The two AR-guard corruption/refusal cases
above (`state-origin-issue-mismatch-refused`, `direct-run-stale-sentinel-run-id-no-retry`)
are additional fail-first regression tests in the same spirit as CHANGE_PLAN
§17's two originals: each must fail against a naive implementation of its
guard (mismatch silently accepted; sentinel `-` treated as a match) and pass
once the guard is correctly implemented.

## 18. Manual-verification strategy

Unchanged from CHANGE_PLAN.md § 18's MV-1…6, plus:

| # | Check | Item |
|---|---|---|
| MV-7 | Clear `.workflow/state`, leave a stale `.workflow/origin` from an unrelated prior issue, run the driver directly with no `STAGEGATE_ORIGIN_*` set to a READY verdict; confirm the issue is not closed | AR-001 |
| MV-8 | Force the `curl` fallback in `from-issue.sh` for a real (disposable) issue, then run the driver directly with authenticated `gh`; confirm the issue is not closed | AR-003 |

## 19. Observability changes

Unchanged from CHANGE_PLAN.md § 19, plus: each new guard prints one
additional, distinct skip/refusal reason on stdout (freshness, provenance,
prefix/origin mismatch, timeout); no existing line is reworded.

## 20. Implementation sequence

Unchanged from CHANGE_PLAN.md § 20 steps 1, 2, 4, 5. Changed/added:

3. ~~Wire `stagegate.sh` to the same lib~~ — dropped (AR-007/AR-009).
6. Extract `scripts/lib/issue-close.sh`; make `from-issue.sh` a thin wrapper.
   Run both suites — all 99 pre-existing checks green, no message edits.
6a. Add the AR-004 prefix/origin comparison to `origin_preflight` and the seed
    gate; add `state-origin-issue-mismatch-refused`. Run both suites.
7. Add the marker file, `WORKFLOW_CLOSE_ISSUE`, `VERDICT_WRITTEN_THIS_RUN`,
   and the `COMPLETE`-branch close, now including the AR-001 freshness signal
   (computed at `ANALYZE` entry) and the AR-003 provenance field/check from
   the start — these are preconditions of the gate being introduced, not a
   later addition, so there is no window where the gate exists without them.
   Add the D test cases plus `direct-run-stale-origin-fresh-state-skips-close`,
   `direct-run-explicit-origin-env-closes`, `curl-fallback-driver-side-skips-close`,
   `legacy-two-field-origin-skips-close`. Run both suites.
7a. Add the AR-002 retry branch and `direct-run-close-retries-on-rerun` /
    `direct-run-stale-sentinel-run-id-no-retry`. Run both suites.
7b. Wrap the close call in a timeout (AR-008); add
    `direct-run-close-timeout-treated-as-failure`. Run both suites.
8. Docs, including the origin third field and all new guards.
9. Full suite run; `IMPLEMENTATION_NOTES.md`, `CHANGE_TEST_REPORT.md`.

## 21. Scope cuts under time pressure

Cut in this order (renumbered; the former #1 is no longer a cut — it is
dropped outright per AR-007/AR-009):

1. The `issue-close.sh` extraction (former step 6) — fall back to A5: a
   self-contained close function inside `change-workflow.sh` reusing the
   identical (now-extended) triple check plus AR-001/002/003/008 guards,
   `from-issue.sh:132-211` untouched. Costs duplication, keeps INV-3 at equal
   strength, removes regression risk from the 99 existing checks.
2. The AR-008 timeout wrap (containment convenience only — a hang is still
   bounded by whatever timeout `gh` itself enforces, per CHANGE_PLAN §11's
   original assumption).
3. The `WORKFLOW_CLOSE_ISSUE` flag (containment only; D is revertible without
   it).
4. `stale-marker-ignored`, `direct-run-close-fails-still-completes` (from
   CHANGE_PLAN §21), and `direct-run-stale-sentinel-run-id-no-retry`.

Never cut: the two CHANGE_PLAN §17 regression tests, this document's two
added AR-guard regression tests, the marker file, the AR-001 freshness guard,
the AR-003 provenance guard, and the AR-004 corruption check — these four are
exactly the findings whose absence would let this change close or resume the
wrong issue, which is a strictly worse outcome than shipping less of item D.

## 22. Risks and unresolved questions

Unchanged from CHANGE_PLAN.md § 22 R-3, R-5, R-6, R-7, R-8. Updated/added:

| ID | Risk | Mitigation |
|---|---|---|
| R-1 | (CHANGE_PLAN, unchanged) B breaks a `state == "COMPLETE"` comparison | Unchanged from CHANGE_PLAN §22. |
| R-2 | (CHANGE_PLAN, unchanged) `issue-close.sh` extraction reworks an asserted message | Unchanged from CHANGE_PLAN §22. |
| R-9 | AR-001: freshness signal computed at the wrong point (e.g. at `COMPLETE` instead of `ANALYZE` entry) would let a run that *became* resumed-looking mid-run (state written by this same run) wrongly count as "resumed" | Compute and hold the signal once, at `ANALYZE` entry, before this run performs any state write (§4/§20 step 7) |
| R-10 | AR-003: a from-issue.sh version predating this change never writes field 3, and an operator error could hand-edit an origin file adding `gh` without it being true | Treated as an accepted residual risk of any manually-edited state file, same class as the pre-existing "hand-edit `.workflow/state`" risk CHANGE_PLAN already accepts elsewhere; not distinguishable from legitimate operator recovery |
| R-11 | AR-007 (deferred): cross-driver race between `stagegate.sh` and `change-workflow.sh` on shared artifacts remains unresolved | Out of scope; recommend a follow-up CR; mitigated only indirectly by not increasing `stagegate.sh`'s coupling to the shared state parser (AR-009) |

## Change-impact table

Unchanged from CHANGE_PLAN.md's change-impact table for the `state.sh`,
`README.md`/`scripts/README.md`, and model-default rows. Changed/added rows:

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/change-workflow.sh:191-218` (`origin_preflight`) | Add AR-004 prefix/origin comparison; compute AR-001 freshness signal | AR-001, AR-004 (deviation from CHANGE_PLAN §5, disclosed) | Medium — new refusal path on every preflight | `state-origin-issue-mismatch-refused`, `direct-run-stale-origin-fresh-state-skips-close` |
| `scripts/from-issue.sh` `write_origin` / `.workflow/origin` format | Add third fetch-provenance field | AR-003 | Low — additive; legacy files fail closed, never open a new hole | `curl-fallback-driver-side-skips-close`, `legacy-two-field-origin-skips-close` |
| `scripts/lib/issue-close.sh` | Add freshness/provenance/retry/timeout preconditions to `issue_close_if_ready` | AR-001, AR-002, AR-003, AR-008 | Medium — same function carries 12 existing asserted strings plus new ones | All `direct-run-*` cases, old and new |
| `scripts/stagegate.sh` | **No change** (dropped from CHANGE_PLAN §4) | AR-007, AR-009 | None (reduces surface) | N/A |

## Traceability

Unchanged from CHANGE_PLAN.md's traceability table for CR Motivation-A and
Motivation-E rows. Changed/added rows:

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| CR Motivation-B (issue number in state), extended | BEH-B (MODIFY) | INV-1 (not weakened), plus new corruption check | `origin_preflight`, `from-issue.sh:22-43` | `state-origin-issue-mismatch-refused` | — |
| CR Motivation-C (zero state on mismatch) | BEH-C (PRESERVE + message) | INV-5 (EXISTING, NOT RELAXED) | `from-issue.sh:58-66` | Unchanged from CHANGE_PLAN.md § traceability | MV-3 |
| CR Motivation-D (close on completion), extended | BEH-D (MODIFY) | INV-3 (STRENGTHENED further: freshness + provenance + bounded retry + timeout) | `lib/issue-close.sh`, `change-workflow.sh:759-799`, `origin_preflight`, `write_origin` | All CHANGE_PLAN §16 D cases plus this document's 8 new cases | MV-4, MV-5, MV-7, MV-8 |

## Frozen change scope

Items B, C, D, E as defined in CHANGE_SPEC.md, exactly as narrowed by
CHANGE_PLAN.md and further narrowed/hardened by the AR-001–004/008 guards and
the AR-007/009 removal of `stagegate.sh` wiring, above. Item A remains
entirely out of scope pending the human's resolution (CHANGE_SPEC §4-A,
unchanged). No other file, behavior, or invariant not named in this document
or CHANGE_PLAN.md may be touched without a new deviation record.

## Files expected to change

`scripts/lib/state.sh` (new), `scripts/lib/issue-close.sh` (new),
`scripts/change-workflow.sh`, `scripts/from-issue.sh`,
`scripts/tests/close-flow-test.sh`, `README.md`, `scripts/README.md`.

## Files that must not change

`scripts/stagegate.sh`, `scripts/workflow.sh`, `scripts/lib/audit-verdict.sh`,
`scripts/codex-review-plan.sh`, `scripts/codex-create-checklist.sh`,
`prompts/**`, `CHANGE_REQUEST.md`, `QUICK_START.md`, all model/effort/turn/
tool defaults, `AGENT_CMD`/`REVIEWER_CMD` defaults, the cost ledger, the lock
implementation (`change-workflow.sh:142-183`), `verify_approval`,
`scripts/tests/audit-verdict-test.sh`, and every reviewer-owned artifact
(`ADVERSARIAL_REVIEW.md`, `MANUAL_CHECKLIST.md`, `FINAL_AUDIT.md`).

## Expected behavioral differences

- `.workflow/state` may carry an `<issue>:` prefix; a prefix that disagrees
  with `.workflow/origin`'s issue is now refused rather than silently
  resolved in origin's favor.
- `.workflow/origin` gains a third field; files lacking it are treated as
  fetched via `curl` for close-eligibility purposes only.
- `change-workflow.sh` itself closes the originating issue at `COMPLETE`
  when origin is present, the verdict is READY, the run is demonstrably
  fresh-with-explicit-binding or resumed, the origin was `gh`-fetched, and
  (new) a prior failed close on the same concrete run id may be retried on a
  later invocation.
- `from-issue.sh`'s own post-run close becomes a defensive fallback, gated by
  the same marker file to avoid a double close.
- `from-issue.sh`'s mismatch refusal message names the manual-clear command.

## Expected unchanged behavior

- `ANALYZE → … → COMPLETE` is the same ordered set of stage tokens.
- Bare (unprefixed) `.workflow/state` files remain readable indefinitely.
- `stagegate.sh` is entirely unmodified — same state handling, same lack of
  issue binding, as today.
- `.workflow/lock/` removal on every exit path (B-8) is unchanged.
- Every string currently asserted by `close-flow-test.sh` is preserved
  verbatim.
- A non-READY verdict, missing origin, unauthenticated `gh`, or
  `WORKFLOW_CLOSE_ISSUE=0` all still skip closing with exit 0, as in
  CHANGE_PLAN §12.

## Exact acceptance criteria

1. CHANGE_SPEC §5's criteria for B, C, D, E, as narrowed by CHANGE_PLAN,
   still hold.
2. `close-flow-test.sh` passes at 125 (CHANGE_PLAN baseline) + ~16
   (CHANGE_PLAN §16) + 8 (this document's §16) = 149 checks, in a clean
   shell, with no message-string edits to any pre-existing assertion.
3. `audit-verdict-test.sh` is unchanged and still green.
4. None of the "files that must not change" (above) has a diff.
5. Every one of AR-001, AR-002, AR-003, AR-004, and AR-008's "Accepted"
   guards has a passing automated test named in §16, above, and that test
   fails against a naive (guard-absent) implementation.
6. The completion report explicitly states that CR Motivation-A is not
   delivered and remains open (AR-005 disposition).
7. MV-1 through MV-8 are executed and recorded per VERIFICATION_REPORT.md's
   normal rules (no BLOCKED/NOT RUN silently converted to PASS).

## Pre-implementation checks

- Confirm `timeout`/`gtimeout` availability in the target environment(s); if
  neither exists, record that AR-008's guard degrades to CHANGE_PLAN §11's
  original unbounded assumption (not an implementation blocker, a disclosed
  gap — see §21 cut #2).
- Confirm the current `close-flow-test.sh` baseline is 125/125 green before
  any edit (CHANGE_PLAN §20 step 1's existing instruction, re-stated as a
  gate here because steps 6a/7/7a/7b depend on a clean starting point).
- Confirm no uncommitted changes exist in any "files expected to change"
  file that would be silently overwritten (core rule 13).

## Post-implementation checks

- Full `close-flow-test.sh` and `audit-verdict-test.sh` runs, recorded in
  CHANGE_TEST_REPORT.md with exact pass counts.
- Diff review confirming no file from "files that must not change" was
  touched.
- Manual confirmation that every new printed reason string is distinct from
  every pre-existing one (no accidental collision that would make a test
  assert the wrong condition).
- MANUAL_CHECKLIST.md and VERIFICATION_REPORT.md completed per MV-1…8.

## First features to cut if time expires

Per updated §21: (1) the `issue-close.sh` extraction (fall back to A5
in-place duplication), (2) the AR-008 timeout wrap, (3) the
`WORKFLOW_CLOSE_ISSUE` flag, (4) `stale-marker-ignored`,
`direct-run-close-fails-still-completes`, and
`direct-run-stale-sentinel-run-id-no-retry`. Never cut: the two CHANGE_PLAN
§17 regression tests, this document's two added regression tests, the marker
file, and the AR-001/AR-003/AR-004 guards themselves (only their
convenience/extraction packaging is cuttable, never their enforcement).

## Conditions that require stopping implementation

- Any pre-existing `close-flow-test.sh` case starts failing and cannot be
  made green without editing an existing asserted message string (signals
  the extraction is not the pure move CHANGE_PLAN §3/§17 assumes).
- `origin_preflight` or `write_origin` changes turn out to require touching
  `verify_approval` or the lock implementation to work correctly — both are
  hard "files that must not change."
- Any AR-001/002/003/004/008 guard cannot be implemented without weakening
  an existing invariant (INV-1, INV-2, INV-3, INV-5) rather than
  strengthening it — stop and return to CHANGE_SPEC for re-approval rather
  than shipping a relaxed invariant unapproved (core rule 6/13 of both
  workflow documents).
- Evidence emerges that `stagegate.sh` does, in fact, need issue-identity
  behavior for some real workflow (contradicting CHANGE_PLAN §4's "prefix is
  empty in practice") — stop and treat it as a new, separate change request
  rather than silently expanding this one's scope.
