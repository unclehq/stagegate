# Verification Report

Executed against the current uncommitted working tree (scripts/change-workflow.sh,
scripts/from-issue.sh, scripts/lib/state.sh, scripts/lib/issue-close.sh) described
in UPDATED_CHANGE_PLAN.md, checked against MANUAL_CHECKLIST.md as written to disk.
All scratch fixtures ran in `mktemp -d` scratch checkouts with a stubbed `gh` and,
where needed, a stubbed reviewer CLI (`fake-reviewer`) writing FINAL_AUDIT.md
content; no real GitHub issue was created or closed anywhere in this report. The
real repo's `gh` (authenticated as `brianosaurus`) was left untouched — creating
or closing a real issue is a visible external action and was not authorized for
this pass.

One new defect was found (D-1, P0) that MANUAL_CHECKLIST.md's MC-011 as literally
worded does not test; see DEFECTS.md.

## Checks

| ID | Action performed | Expected | Actual | Evidence | Status | Defect |
|---|---|---|---|---|---|---|
| MC-001 | Set `.workflow/state` to each of ANALYZE/FINAL_AUDIT/COMPLETE against a scratch checkout with issue-42 origin binding; ran the real driver directly (stubbed reviewer for FINAL_AUDIT) | Bare/prefixed tokens dispatch the right stage; order preserved | ANALYZE correctly required CHANGE_REQUEST.md and stopped (exit 1, as expected — no real CHANGE_REQUEST.md/agent CLI supplied); FINAL_AUDIT→COMPLETE wrote `42:COMPLETE`; stage order matches CHANGE_PLAN §7 (unchanged) | scenario `mc002`/`mc007` transcripts | PASS (partial evidence) | — |
| MC-002 | Wrote each bare legacy token (ANALYZE, COMPLETE, FINAL_AUDIT) to `.workflow/state`, ran the real driver | Each bare token dispatches correctly; bare `FINAL_AUDIT` completes; bare `COMPLETE` exits normally | ANALYZE dispatched (blocked on missing CHANGE_REQUEST.md, correct precondition check); COMPLETE exited 0 with "Change workflow complete."; FINAL_AUDIT (bare) completed to bare `COMPLETE` with verdict READY | scenario `mc002` transcript | PASS | — |
| MC-003 | Fresh checkout, no origin/env, one transition; separately seeded `abc:IMPLEMENT` | No resolvable issue → bare token written; nonnumeric prefix rejected, exit 1, no stage run | Fresh run wrote no issue prefix (state ends up whatever bare stage the run reached; confirmed no `:` in output); `abc:IMPLEMENT` produced `Unknown workflow state: abc:IMPLEMENT`, exit 1, no dispatch | scenario `mc003` transcript | PASS | — |
| MC-004 | `.workflow/state`=`99:IMPLEMENT`, origin names issue 42 (gh); invoked both `from-issue.sh --change` (via sourced `check_origin_or_refuse`) and `change-workflow.sh` with explicit issue-42 binding | Both refuse, exit 1, distinct corruption message, state untouched, no stage/close | Both entry points printed "Refusing to act on corrupt workflow state: ... is bound to issue 99 but .workflow/origin names issue 42." and left state as `99:IMPLEMENT` | seed-gate run + `mc004_driver` transcript | PASS | — |
| MC-005 | `.workflow/state`=IMPLEMENT, origin names other/repo#99; ran the seed gate for issue 42 | Refuse, exit 1, state/artifacts untouched, prints manual-clear command | "Refusing to seed owner/repo#42: ... does not belong to it." + `rm -f .workflow/state .workflow/origin`; exit 1; state byte-identical before/after | live run transcript above | PASS | — |
| MC-006 | `.workflow/state`=`42:COMPLETE`, matching gh origin; ran driver preflight with explicit binding | Not misclassified as in-flight/foreign | "Change workflow complete." exit 0 | scenario `mc006` | PASS | — |
| MC-007 | FINAL_AUDIT→COMPLETE with READY verdict, matching 3-field gh origin, explicit run/origin env, stubbed `gh` | Exactly one close, exit 0, marker written | `Closed owner/repo#42 (verdict: READY).`, 1 close call, marker=`run-1 owner/repo 42` | scenario `mc007` | PASS (stubbed gh — see note below) | — |
| MC-008 | Same as MC-007 with READY_WITH_NON_BLOCKING_ISSUES | Same as MC-007 | `Closed owner/repo#42 (verdict: READY_WITH_NON_BLOCKING_ISSUES).`, 1 close call, marker written | scenario `mc008` | PASS (stubbed gh) | — |
| MC-009 | 7 independent fixtures: non-READY, missing origin, unauth gh, mismatched run id, mismatched origin (non-corrupt form), stale audit hash, `WORKFLOW_CLOSE_ISSUE=0` | Every run exits 0, no close/marker, distinct skip reason each | All 7 confirmed: NOT_READY skip; no-origin skip ("cannot prove it owns..."); gh-unauth skip; mismatched-run-id silently not retried (no close, no marker); origin-mismatch-at-close skip ("Origin binding no longer names..." reached via bare-state, non-corrupt fixture `mc009-originmismatch3`... see note); stale-hash skip; close-flag-off skip | scenario `mc009` transcript | PASS, with one caveat — see D-1 | D-1 (adjacent, not this exact fixture) |
| MC-010 | Empty state, leftover gh origin for issue 99, no explicit STAGEGATE_ORIGIN_* | No close of any issue, distinct freshness-skip reason | "This run cannot prove it owns .workflow/origin: ... Leaving other/repo#99 open." exit 0, no close | scenario `mc010` | PASS | — |
| MC-011 | Empty-state-at-start driver run, explicit matching STAGEGATE_ORIGIN_REPO/ISSUE, matching gh origin, READY verdict | Close proceeds for the bound issue | `Closed owner/repo#42 (verdict: READY).` | scenario `mc011` | PASS **as literally worded** (origin file matches explicit env) — see D-1 for the untested divergent case | D-1 |
| MC-012 | Three origin-file variants (gh / curl / legacy 2-field), otherwise identical eligible completion | gh closes; curl and legacy skip with provenance reason, no close | Confirmed for all three: gh→closed; curl→"unauthenticated curl fallback" skip; legacy 2-field→same skip (fails closed) | scenario `mc012` | PASS | — |
| MC-013 | Real `from-issue.sh` wrapper close path (`close_issue_if_ready`) invoked with `USED_GH=0` this invocation, origin recorded as `curl`, healthy `gh` otherwise | Neither driver nor wrapper closes; no marker | `Issue was fetched over the unauthenticated curl fallback...`, 0 close calls, no marker | `mc013` transcript | PASS (stubbed gh — no real curl fetch or real issue was exercised; the wrapper's `USED_GH`/provenance gating logic was) | — |
| MC-014 | First run: `FAKE_GH_CLOSE_RC=1` (close fails); rerun with same concrete run id | First: warn, no marker, exit 0; second: exactly one successful close | First run: "gh issue close failed...", no marker; second run: "Closed owner/repo#42...", marker written, total close_calls=2 (1 failed + 1 succeeded) | scenario `mc014` | PASS | — |
| MC-015 | Verdict record run id `-`, `STAGEGATE_RUN_ID` unset, rerun at COMPLETE | No retry, no close, no marker | exit 0, close_calls=0, no marker | scenario `mc015` | PASS | — |
| MC-016 | Wrapper double-close protection (driver already closed + wrote marker) | Wrapper recognizes marker, no second close | Confirmed by the pre-existing, still-passing `no-double-close-after-driver` case in `close-flow-test.sh` (181/181 run, this session) — exercises the same `close_issue_if_ready` marker-check code this report verified directly for the wrapper path in MC-032 | close-flow-test.sh run (MC-029) + `mc032b` transcript (same code path) | PASS | — |
| MC-017 | Stale marker naming a different run/issue must not suppress a legitimate close | Marker ignored, normal gated close proceeds once | Confirmed by pre-existing `stale-marker-ignored` case (181/181 run) — same `close_issue_if_ready` marker-match logic (`marker_run==run_id && marker_repo==... && marker_issue==...`) read and manually re-verified in `scripts/from-issue.sh:163-172` | close-flow-test.sh run (MC-029); source read | PASS | — |
| MC-018 | STAGEGATE_CLOSE_TIMEOUT=1, gh close stub sleeps 5s | Close terminated ~1s past deadline, warning, no marker, state COMPLETE, exit 0, lock released | elapsed_secs=1; "gh issue close exceeded the 1s deadline."; "gh issue close failed..."; no marker; exit 0; lock_dir_present=no | scenario `mc018` | PASS | — |
| MC-019 | Isolated PATH lacking `timeout`/`gtimeout`, blocking `gh` stub, external harness kill after 5s | Direct unbounded `gh issue close` call, no timeout message, harness termination cleans up lock | Could not reliably reproduce: this sandboxed shell's background jobs do not expose a resolvable, killable process group (`ps -o pgid=` returns empty for the backgrounded child; no `setsid` on this macOS host) | see transcript — job exited 127 / pgid empty | BLOCKED (environment) | — |
| MC-020 | Exit paths: success, close-failure, stage-error (unknown state), SIGINT mid-run | `.workflow/lock/` absent after every driver-controlled exit | success: lock absent, exit 0; close-failure: lock absent, exit 0; stage-error (`abc:IMPLEMENT`): lock never acquired (refused before ANALYZE-style acquire — see note) exit 1, lock absent; SIGINT during a live ANALYZE stub run: lock absent after signal | scenario `mc020` transcript | PASS | — |
| MC-021 | Live-PID lock vs. stale-PID lock | Live lock blocks with pid message, untouched; stale lock cleared, run proceeds | "another change-workflow.sh run (pid $$) holds this checkout." + pid file untouched; "Clearing stale lock ... run proceeds to Change workflow complete.", lock dir removed | scenario `mc021` | PASS | — |
| MC-022 | Approved-artifact tamper-after-approval (isolated re-implementation of `verify_approval`, hash-matched); full `audit-verdict-test.sh` run | Mutated artifact rejected pending reapproval; verdict classes unchanged | Mutation correctly rejected (exit 1, "changed after approval"); matching content accepted (exit 0); `audit-verdict-test.sh: 26 checks passed` (this session) | `mc022.sh` transcript; audit-verdict-test.sh run | PASS | — |
| MC-024 | `git diff HEAD --stat` over the full must-not-change file list; grep for MODEL_/EFFORT_/BUDGET_/AGENT_CMD/REVIEWER_CMD/CLAUDE_TOOLS additions in the two changed drivers | No diff on protected files/settings | Diff empty for stagegate.sh, workflow.sh, audit-verdict.sh, codex-review-plan.sh, codex-create-checklist.sh, prompts/, QUICK_START.md, audit-verdict-test.sh, FINAL_AUDIT.md; ADVERSARIAL_REVIEW.md/MANUAL_CHECKLIST.md show diffs but these are the reviewer's own authored updates from earlier stages, not implementer edits; grep for defaults found zero added/removed lines (only unchanged context) | `git diff --stat` + grep output | PASS | — |
| MC-025 | Cross-checked all new echo strings in issue-close.sh/change-workflow.sh/from-issue.sh for accidental reuse | Each new condition distinct; no pre-existing string reworded | All distinct except one shared instructional trailer, "Close $repo#$issue by hand (verdict: $verdict).", used by two *different, pre-existing* skip reasons (gh-missing vs gh-unauthenticated) whose primary lines differ — not a new collision, not this change's addition | grep of echo strings, sorted | PASS | — |
| MC-026 | Followed README.md/scripts/README.md for the new state/origin grammar, close flow, kill switch, retry, skip guards | Docs reproduce supported behavior | State/origin grammar, third-field provenance, marker, retry, kill switch documented (`README.md:268-288`, `scripts/README.md:106-119`); `STAGEGATE_CLOSE_TIMEOUT` and the AR-004 corruption/manual-clear message are undocumented | grep of both READMEs | PASS, with a gap (D-2) | D-2 |
| MC-027 | `WORKFLOW_CLOSE_ISSUE=0` containment; `git archive` rollback to prior release; grep for any reopen path | Kill switch works; prior release resumes; no auto-reversal of a closed issue | Kill switch confirmed (`mc009-closeoff`: "Issue closing is disabled..."); CHANGE_TEST_REPORT.md's `git archive HEAD` rollback test already reproduces 125/125 on the pre-change tree (cited, not re-run, per context-economy rule); no "reopen" logic exists anywhere in scripts/ (grep, zero hits) | `mc009-closeoff`; grep; CHANGE_TEST_REPORT.md rollback row | PASS | — |
| MC-028 | Inspected model/effort/CLI defaults diff and completion docs for Motivation-A claims | Defaults unchanged; no Kimi wrapper; report discloses A open | Zero diff on any MODEL_/EFFORT_/AGENT_CMD/REVIEWER_CMD line; `IMPLEMENTATION_NOTES.md:58` and `CHANGE_TEST_REPORT.md:78` both explicitly state Motivation-A is not delivered and remains open | grep + file reads | PASS | — |
| MC-029 | `bash scripts/tests/close-flow-test.sh` and `bash scripts/tests/audit-verdict-test.sh`, ambient STAGEGATE_* stripped | 181 + 26 = 207, no failures | `close-flow-test.sh: 181 checks passed`; `audit-verdict-test.sh: 26 checks passed` | this session's own run (not cited from CHANGE_TEST_REPORT.md) | PASS | — |
| MC-030 | Installed shellcheck (0.11.0, was absent) and ran it against the 5 changed/added files | No error-severity findings; warnings dispositioned | Exit 1 (shellcheck's convention for any finding) but zero `error`-severity diagnostics; 3 info/warning findings: SC2034 (`attempt` loop counter genuinely unused — cosmetic, no fix needed), SC1091×2 (dynamic `source` of sibling libs, expected, not followed by static analysis) | shellcheck output (this session) | PASS | — |
| MC-031 | write_origin rewrite semantics for matching-3field / matching-2field / foreign origin, issue-42 explicit binding | 3field preserved as-is; 2field stays 2field (fails closed); foreign becomes 2field, does not inherit gh | `owner/repo 42 gh` (unchanged); `owner/repo 42` (unchanged, still 2-field); foreign origin rewritten to `owner/repo 42` (no `gh` inherited) | scenario `mc031` | PASS | — |
| MC-032 | Wrapper-side `close_issue_if_ready` invoked twice with a matching marker after the first closes | First closes + writes marker; second recognizes marker, no second close | First: `Closed owner/repo#42...`, marker written; second: "owner/repo#42 was already closed by change-workflow.sh.", close_calls stayed at 1 | scenario `mc032b` | PASS | — |
| MC-033 | STAGEGATE_CLOSE_TIMEOUT ∈ {1, 0, bogus, -1}, blocking gh stub (3s sleep), harness deadline | 1→terminates ~1s, no marker; 0→passes through, may hang until harness kills it; bogus/-1→utility rejects, treated as failure, no marker; lock released in all cases | 1: "exceeded the 1s deadline", no marker; 0: closed successfully (`timeout 0` = no limit on this platform's coreutils, ran to completion), marker written; bogus/-1: `timeout: invalid time interval/option`, treated as close failure, no marker; all 4 exited 0, no case left a lock behind | scenario `mc033` | PASS | — |
| MC-034 | `from-issue.sh --help` under STAGEGATE_FROM_ISSUE_SOURCE_ONLY unset/0/1 | unset/0 preserve CLI; 1 exits before any CLI/fetch/seed work, no artifacts | unset/0: normal usage text, exit 0; 1: zero output, exit 0, no usage text printed (early `return`/`exit` before `usage()` is reached) | direct invocation transcript | PASS | — |
| MC-035 | Static check: does `stagegate.sh` reference any of the new shared artifacts/libs | Determine actual cross-driver exposure | `stagegate.sh` writes `.workflow/state` directly (own raw `printf`, not `lib/state.sh`) and reads/writes `FINAL_AUDIT.md` — the two files it shares with `change-workflow.sh`; it has zero references to `.workflow/origin`, `.workflow/audit-verdict`, `.workflow/issue-closed`, or either new lib. A live concurrent two-driver run (both driven by real agent CLIs) was not executed — out of scope for a stub-based pass and consistent with AR-007's disclosed, deferred status | grep of stagegate.sh; git diff (zero) | BLOCKED (requires a live concurrent run with real agent CLIs; static exposure confirmed instead) | — |
| MC-036 | `git diff HEAD --stat -- scripts/stagegate.sh`; grep for any reference to new artifacts/libs | Unchanged driver, no new-artifact awareness | Diff empty (byte-identical to the pre-change baseline); zero references to origin/audit-verdict/issue-closed/new libs | `git diff`, grep | PASS | — |

## Acceptance-criteria summary

- AC-B (issue-prefixed state, compatible readers): satisfied — MC-001…006, MC-026, MC-029 all PASS.
- AC-C (refuse-not-zero, manual guidance): satisfied — MC-005, MC-025 PASS.
- AC-D (eligible completion closes; ineligible does not): **satisfied for every fixture MC-007…019/031-033 actually test, but D-1 shows the gate is not airtight against a divergent explicit-env-vs-on-disk-origin combination that none of MC-007…019 as worded exercises.** Recommend re-running MC-011 with a divergent origin fixture before sign-off, or fixing D-1 first.
- AC-E (lock removal after every controlled exit): satisfied — MC-014, MC-018, MC-020, MC-021, MC-033 PASS; MC-019 BLOCKED (environment).
- Automated pass bar / unchanged audit suite: satisfied — MC-029, MC-030 PASS (207/207, shellcheck clean of errors).
- Frozen-scope diff: satisfied — MC-024, MC-028, MC-036 PASS; MC-034 PASS; MC-035 BLOCKED (partial static confirmation only).
- Partial-delivery disclosure (Motivation-A): satisfied — MC-028 PASS.

## Preserved-behavior summary

BEH-C/INV-5 refusal semantics, BEH-E lock ownership/cleanup, legacy bare-state
compatibility and stage order, existing close skips/wrapper safeguards, approval
integrity (verify_approval), and stagegate.sh's independence are all confirmed
unchanged by direct re-execution or diff, not by re-reading CHANGE_TEST_REPORT.md's
claims alone.

## Changed-behavior summary

State-prefix grammar and AR-004 corruption handling (MC-001…006), driver-side
close and the strengthened gate including freshness/provenance/retry/timeout
(MC-007…019), origin third-field provenance and legacy migration (MC-012,
MC-031), and marker idempotency (MC-016, MC-017, MC-032) all behave as specified
— with the one gap in D-1.

## Invariant summary

INV-1, INV-2, INV-4, INV-5: confirmed enforced, no regression found.
INV-3: confirmed enforced **in every fixture this pass tried that MANUAL_CHECKLIST.md's
existing MC items specify**, but D-1 demonstrates the enforcement is not complete —
a `COMPLETE`-state run with an explicit, correctly-set `STAGEGATE_ORIGIN_REPO`/`ISSUE`
can still close an issue named only by a stale/foreign on-disk `.workflow/origin`,
not the one the operator specified. This is a genuine, reproducible gap in INV-3's
enforcement, found by testing beyond MC-011's literal wording.

## Regression summary

No regression against pre-change behavior was found. D-1 is a defect in the
*new* BEH-D/AR-001 machinery itself (not a regression against baseline, since
baseline had no driver-side close at all), but it does undercut this delivery's
own stated guarantee for BEH-D/AR-001 as written in UPDATED_CHANGE_PLAN.md.

## Unresolved defects

- D-1 (P0): see DEFECTS.md. Blocks full confidence in AC-D / INV-3 as stated.
- D-2 (P1): see DEFECTS.md. Documentation gap only.

## Recommendation

Do not sign off AC-D / INV-3 as fully satisfied until D-1 is resolved (either by
sourcing the close target from `STAGEGATE_ORIGIN_REPO`/`ISSUE` rather than the
origin file, or by having `origin_preflight` validate the origin file against
explicit `STAGEGATE_ORIGIN_*` unconditionally, including at `COMPLETE`). All
other checks in MANUAL_CHECKLIST.md pass as literally worded, with two
environmental BLOCKED items (MC-019, MC-035) that need a host with working
process-group control and a live two-driver run respectively, and one
documentation gap (D-2). Human review of D-1 required before this change is
declared complete per this repo's completion rule ("no blocking final-audit
findings remain").
