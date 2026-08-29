# Change Spec

Omitted sections: Migration requirements (no data migration, only file-format and script edits); Prototype-isolation requirements (no prototype requested)

## 1. Change type

Bundle of 5 independent sub-changes: Config default (A), Data format (B),
Safety-mechanism policy (C), Feature/bug fix (D), Verification-only (E, no
code change expected). Per BASELINE_REPORT.md §16, tracked here as separate
items so each can be approved/rejected independently rather than as one
atomic change.

## 2. Problem statement

`CHANGE_REQUEST.md` (from `unclehq/stagegate#3`) bundles 5 asks, one of which
(A) is internally self-contradictory and one of which (C) conflicts with a
deliberately-designed existing safety invariant (I-5). This spec resolves what
can be resolved from the text as written and marks the rest UNRESOLVED,
per baseline §15-16.

## 3. Current behavior

See BASELINE_REPORT.md §4 (B-1 through B-9) and §6. Not restated here.

## 4. Desired behavior

**A — Model defaults (opus vs. kimi).** UNRESOLVED — see §16. No spec commitment
until the human picks one interpretation.

**B — Prepend issue number to `.workflow/state`.** Format changes from a bare
stage token (`IMPLEMENT`) to an issue-number-prefixed token. Exact delimiter/
grammar is an implementation decision (out of scope for this doc), but the
spec commits to: (1) every reader/writer in BASELINE_REPORT.md §6/§13 is
updated in the same change, (2) `.workflow/origin` remains the sole
authority for origin-match decisions (I-1) — the issue number in `state` is
informational/redundant, never a second source of truth, so B does not
weaken I-1.

**C — Zero `.workflow/state` on issue-number mismatch in `from-issue.sh`.**
Rejected as literally requested (see §16) — auto-zeroing on mismatch
reopens AR-001 (I-5). Desired behavior instead: `from-issue.sh` continues to
refuse and exit 1 on mismatch (current B-5 behavior, unchanged), and prints
guidance naming the exact manual command to clear state, rather than
clearing it automatically. No invariant is relaxed.

**D — Close issue on `change-workflow.sh` completion.** Extend issue-closing
(currently only reachable via `from-issue.sh`'s post-run check, B-9) so that
`change-workflow.sh` itself closes the originating issue when it reaches
`COMPLETE`, provided `.workflow/origin` is present and the same READY-verdict
gating in I-3 is met — regardless of whether the run was launched directly
or via `from-issue.sh`. `from-issue.sh`'s existing post-run check becomes
redundant/defensive rather than the only path.

**E — Remove `.workflow/lock/lock` on completion.** No literal file named
`lock` inside `.workflow/lock/` exists today (baseline §15); the whole
`.workflow/lock/` directory is already removed on every driver-controlled
exit path (B-8). Desired behavior: unchanged/PRESERVE. Treated as already
satisfied pending confirmation of what "lock/lock" was meant to name (§16).

## 5. Acceptance criteria

| Item | Acceptance criteria |
|---|---|
| A | Human has selected exactly one of {all-opus, all-kimi, per-stage-unchanged, other} before any model-default line is edited. Not satisfied until resolved. |
| B | Every consumer in baseline §6/§13 (`change-workflow.sh`, `stagegate.sh`, `from-issue.sh`, `scripts/workflow.sh`, `close-flow-test.sh` literal fixtures, `README.md`, `QUICK_START.md`) reads/writes the new format consistently; `close-flow-test.sh` passes at 125/125 in a clean shell. |
| C | `from-issue.sh --change` invoked with mismatched issue number still refuses (exit 1, non-zero state), and I-1/I-5 remain enforced with no regression in `close-flow-test.sh`'s origin-mismatch cases. |
| D | A `change-workflow.sh` run started directly (no `from-issue.sh`), with `.workflow/origin` present and a READY/READY_WITH_NON_BLOCKING_ISSUES verdict, closes the originating issue by the time the process exits `COMPLETE`; a non-READY verdict does not close it. |
| E | `.workflow/lock/` (directory and all contents) is absent immediately after any `change-workflow.sh` exit, success or failure — confirmed by re-running the existing lock-release test cases with no new failures. |

## 6. Observable behavior table

| ID | Class | Trigger | Current behavior | Expected behavior | Verification |
|---|---|---|---|---|---|
| BEH-A | EXPERIMENTAL | Driver run with no model overrides | B-1/B-2 (tiered opus/sonnet) | UNRESOLVED — no change until human resolves opus-vs-kimi contradiction | N/A until resolved |
| BEH-B | MODIFY | Any stage transition in either driver | B-4 (bare token, no issue number) | State token carries the current issue number in addition to the stage | Updated `close-flow-test.sh` state-format assertions; manual read of `.workflow/state` after a transition |
| BEH-C | PRESERVE | `from-issue.sh --change` with mismatched (repo, issue) and non-empty/non-`COMPLETE` state | B-5 (refuse, exit 1, state untouched) | Same refusal; message additionally names the manual-clear command | Existing `close-flow-test.sh` `preflight-origin-mismatch`/`preflight-origin-absent` cases continue passing; manual message check |
| BEH-D | MODIFY | `change-workflow.sh` reaches `COMPLETE` with `.workflow/origin` set and READY verdict, run started directly (not via `from-issue.sh`) | B-9 gap: issue stays open (only `from-issue.sh`'s post-run path closes it) | Issue is closed by `change-workflow.sh` itself before/at exit | New test case mirroring existing `close-flow-test.sh` verdict-record-written / issue-close cases, run without the `from-issue.sh` wrapper |
| BEH-E | PRESERVE | Any `change-workflow.sh` exit | B-8 (`.workflow/lock/` removed via EXIT trap) | Unchanged | Existing `close-flow-test.sh` lock cases (`lock-held-by-live-pid`, `lock-stale-pid-cleared`) |

## 7. Invariant table

| ID | Status | Invariant | Scope | Enforcement point | Verification |
|---|---|---|---|---|---|
| INV-1 | EXISTING | A resumed run may not act on `.workflow/state` unless `.workflow/origin` proves it belongs to the current (repo, issue) (=I-1) | Both drivers, `from-issue.sh` | `change-workflow.sh:191-218`, `from-issue.sh:47-67` | `close-flow-test.sh` origin-mismatch cases must keep passing after BEH-B/BEH-C |
| INV-2 | EXISTING | Only one `change-workflow.sh` may hold a checkout at a time (=I-2) | `change-workflow.sh` | `mkdir` lock, `:147-183` | `close-flow-test.sh` lock cases |
| INV-3 | STRENGTHENED | The GitHub issue is closed only when the verdict record's run id, origin binding, and `FINAL_AUDIT.md` hash all match the current run (=I-3, extended to fire from inside `change-workflow.sh` per BEH-D, not only from `from-issue.sh`) | Both entry points | `from-issue.sh:132-211` (existing) + new enforcement inside `change-workflow.sh` (BEH-D) | New test case (§6 BEH-D) plus existing `close-flow-test.sh` verdict cases |
| INV-4 | EXISTING | An approved artifact whose bytes change is re-hashed and rejected (=I-4) | `change-workflow.sh` | `verify_approval` | Not otherwise exercised by this change; no code path here touches it |
| INV-5 | EXISTING — NOT RELAXED | `.workflow/state` is never auto-deleted to resolve a foreign-owner conflict (=I-5) | `from-issue.sh` preflight | Refuse-not-zero design, `UPDATED_CHANGE_PLAN.md:53` | `close-flow-test.sh` origin-mismatch cases; CR Motivation-C's literal "zero state" ask is REJECTED to keep this invariant intact — see §16 |

No invariant here is RELAXED or REMOVED. INV-5 is explicitly flagged: the
change request's literal text (Motivation-C) asks for behavior that would
relax it; this spec rejects that reading rather than relaxing the invariant,
per baseline §15 and core rule 6/13. If the human wants INV-5 actually
relaxed, that requires a separate, explicit approval re-opening this
decision.

## 8. Compatibility requirements

- BEH-B changes an on-disk file format read by 5+ consumers (baseline §6);
  all must move together in the same change — no dual-format transition
  period, since nothing else depends on the old format surviving.
- `README.md`, `scripts/README.md`, `QUICK_START.md` documented contracts
  (baseline §6, §13) must be updated in the same change as BEH-B/BEH-D to
  avoid drift.

## 9. Error and failure behavior

- BEH-D: if `.workflow/origin` is absent, or the verdict is not
  READY/READY_WITH_NON_BLOCKING_ISSUES, `change-workflow.sh` must not attempt
  to close the issue and must not error the run — completion proceeds,
  closing is simply skipped (mirrors current `from-issue.sh` behavior,
  `scripts/from-issue.sh:132-211`).
- BEH-C: refusal path's exit code (1) and untouched-state guarantee are
  unchanged; only the printed message gains the manual-clear hint.

## 10. Performance requirements

None stated or implied; no change here is performance-sensitive.

## 11. Security requirements

- BEH-D must reuse the existing hash/run-id/origin triple-check (I-3) rather
  than introduce a second, looser gate for the direct-run path — a weaker
  duplicate check would let a stale or foreign run close an issue it
  doesn't own.

## 12. Rollback expectations

- Each of A/B/C/D/E is independently revertible: B is a file-format change
  confined to this repo's own scripts/tests/docs (no external consumers
  identified); D adds a code path but does not remove the existing
  `from-issue.sh` closing path, so reverting D leaves B-9 behavior intact;
  C makes no code change (rejects the request); E makes no code change.

## 13. Explicit non-goals

- Not touching `stagegate.sh`'s new-application-only behavior beyond any
  shared model/CLI defaults resolved under A (baseline §14).
- Not implementing literal "zero `.workflow/state` on mismatch" (Motivation-C)
  — see INV-5 and §16.
- Not writing a `kimi` CLI wrapper or validating `kimi` flag-compatibility —
  out of scope until A is resolved.
- Not modifying `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`,
  `GOOD_FIRST_ISSUES.md`, `STRATEGY.md`, `AGENTIC.md`, or `prompts/` bodies
  (baseline §14).

## 14. Assumptions and unresolved questions

Carried forward from baseline §15, with resolutions/dispositions:

1. **A (opus vs. kimi) — UNRESOLVED.** Summary says "everything opus";
   Motivation-A says "everything kimi." No default-model edit proceeds to
   CHANGE_PLAN.md until the human states which is meant (or a third option:
   leave per-stage tiering as-is).
2. **A — "kimi" drop-in feasibility — UNRESOLVED.** Even once direction is
   picked, whether `kimi` accepts the same CLI flags as `claude`/`codex`
   (required per `README.md:258-260`) is unverified; no `kimi` binary
   available in this environment to test.
3. **C (zero-state-on-mismatch) — RESOLVED as rejected**, per INV-5/§16:
   implementing it literally would reopen AR-001. This spec substitutes
   BEH-C (refuse + better message) as the compliant interpretation of the
   underlying request ("so `change-workflow.sh` will complete properly" —
   satisfied by telling the operator how to clear state safely, not by
   auto-clearing it).
4. **B (state format) — RESOLVED as additive-safe, format-changing.** The
   issue number is added to the token consumers already parse; `.workflow/
   origin` remains the sole trust source for INV-1, so the format change
   does not itself weaken any invariant. Exact grammar left to CHANGE_PLAN.md
   (implementation detail).
5. **E ("lock/lock") — UNRESOLVED naming, RESOLVED behaviorally.** No such
   file exists; `.workflow/lock/` directory removal already satisfies the
   apparent intent (B-8). If the human meant a different, currently
   nonexistent path, this spec does not cover it — needs clarification.
6. CHANGE_REQUEST.md itself supplies no acceptance criteria, constraints, or
   out-of-scope list (baseline §1) — §5/§13 above are this document's
   substitute, subject to human approval.
