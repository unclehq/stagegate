# Updated Change Plan

Supersedes CHANGE_PLAN.md where they conflict. CHANGE_PLAN.md is hash-approved
and immutable; sections below not reproduced are unchanged from it.

## 0. Disposition of adversarial findings

| Finding | Disposition | Reason | Exact plan change |
|---|---|---|---|
| AR-001 (`workflow.sh --help` side-effecting) | Accepted | `mkdir -p .workflow/approvals` at `workflow.sh:7` runs before dispatch; CHANGE_SPEC §4/§9 require help/version/unknown-arg handling before any side effect on all six scripts, and CHANGE_PLAN §5 incorrectly froze this ordering. Verified by reading `scripts/workflow.sh:1-10`. | §1/§4 below: insert a standalone `-h\|--help\|""` early-exit **before** `mkdir -p .workflow/approvals`, ahead of the existing full `case`. |
| AR-002 (uniform unknown-arg stream not implemented) | Partially accepted | Spec §4's "any of the six scripts → stderr" reading contradicts BH-15/BH-16, both already-approved PRESERVE behaviors for `workflow.sh`'s unknown-subcommand path and `from-issue.sh` in full. Rewriting either would violate Core rule 5 (no unrelated cleanup) and BH-16's explicit "no source change." Resolving CHANGE_PLAN's own Q-1: the stderr contract applies only to the four scripts that get a new guard in this change (`stagegate.sh`, `change-workflow.sh`, `codex-review-plan.sh`, `codex-create-checklist.sh`); `workflow.sh`'s `*)` branch and all of `from-issue.sh` keep their current stdout stream, per BH-15/BH-16. This is a scoping clarification of CHANGE_SPEC §4, not a plan change to source. | §1 convention table: add an explicit row scoping the stderr rule to the four newly-guarded scripts; document the `workflow.sh`/`from-issue.sh` exception inline instead of leaving it as unresolved Q-1. |
| AR-003 (IV-03 relaxation lacks recorded approval) | Accepted | CHANGE_SPEC §13 already states the relaxation "requires explicit approval before implementation"; CHANGE_PLAN §8 asserted approval without evidence. The spec gate approved the *document*, not necessarily this specific line. | New §7 (Pre-implementation checks): implementation of the `workflow.sh` no-arg/`-h`/`--help` → exit 0 change may not begin until the human approval of *this* document explicitly reaffirms IV-03's relaxation. If not explicit, implement only `-h`/`--help` → exit 0 and leave bare no-args at exit 1 (deviation recorded in IMPLEMENTATION_NOTES.md). See §10 stopping conditions. |
| AR-004 (`bash -n scripts/*.sh` only checks the first file) | Accepted | Confirmed: bash treats the first glob expansion as the script path and the rest as `$1`, `$2`, ... of that script, not as separate files to check. | §12 (T-11) revised: loop `for f in scripts/*.sh; do bash -n "$f"; done`, failing on first non-zero. |
| AR-005 (guard checks `$1` only, ignores trailing args) | Accepted | CHANGE_SPEC §4 requires rejecting "any unrecognized flag/argument"; silently ignoring `--help --bogus` contradicts that even though it was defensible as "unreachable in documented use." | §1 guard shape revised to branch on `$#` together with `$1` (see below); any arg count other than the exact recognized case falls to the unknown-argument branch. Applies to all five guarded scripts. |
| AR-006 (preserved zero-arg behavior never actually verified) | Accepted | T-13 exercises only T-01..T-11, none of which invoke any script with zero arguments; the fall-through path (the one behavior these scripts must *not* change) is the one path never checked. | §12 adds T-14: pre/post-change zero-argument comparison for both drivers (stubbed `WORKFLOW_*_CMD=false`) and both `codex-*` helpers, under the §11 containment. |
| AR-007 (containment fixture can hide `.workflow` mutation) | Accepted | `cp -R` copies this repo's existing (gitignored) `.workflow/` directory into the fixture; a broken guard could mutate it and `git status --porcelain` would never see it, since the directory is ignored either way. | §11 rewritten: use `git worktree add --detach <tmp> HEAD` (clean checkout, no gitignored content carried over) instead of `cp -R`; assert `.workflow` absence directly via `test ! -e .workflow` / `find .workflow` before and after every invocation, not via `git status`. |
| AR-008 (usage text could be copy-pasted between scripts and still pass) | Accepted | T-05/T-06/T-12 only check exit code and non-emptiness; a swapped `usage()` body between the two `codex-*` scripts would pass every test as written. | §12 (T-05, T-06, T-12) revised: assert each script's help output contains that script's own basename and rejects the other's syntax; T-06 extended to cover both `codex-*` scripts, not only `codex-review-plan.sh`. |
| AR-009 (byte-identical regression checks have no captured baseline) | Accepted | BASELINE_REPORT §9 is prose; there is no captured file or hash to `cmp` against for T-08/T-09/T-10. | §16 implementation sequence: new step 0 captures golden stdout/stderr/exit-status files for `workflow.sh status`, `workflow.sh bogus-subcommand`, and all three `from-issue.sh` preserved forms *before* touching any script; T-08/T-09/T-10 diff against these files with `cmp`, not against the prose baseline. |

## 1. Selected technical approach

Retains the per-script inline guard from CHANGE_PLAN §1, with two corrections
driven by AR-001 and AR-005.

**Guard shape for `stagegate.sh` / `change-workflow.sh`** (unchanged insertion
point: after `cd "$ROOT"`, before `STATE_DIR=`), now discriminating on `$#`
together with `$1` so trailing arguments cannot be silently ignored:

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

case "$#:${1:-}" in
    0:)                 ;;
    1:-h|1:--help)      usage; exit 0 ;;
    1:--version)        printf '%s\n' "$STAGEGATE_VERSION"; exit 0 ;;
    *)                  printf 'Unknown argument: %s\n' "${1:-}" >&2; usage >&2; exit 1 ;;
esac
```

`codex-review-plan.sh` / `codex-create-checklist.sh`: same shape minus the
`--version` arm, inserted before the `test -s ...` precondition block.

**`workflow.sh`** (revised for AR-001): the help/empty early-exit must run
*before* `mkdir -p .workflow/approvals` (currently line 7), not merely before
the existing `*)` branch (line 75), because line 7 is a side effect that
currently runs unconditionally on every invocation including `--help`. New
structure:

```sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
    cat <<'EOF'
Usage:

  ./scripts/workflow.sh approve-plan
  ./scripts/workflow.sh approve-review
  ./scripts/workflow.sh approve-updated-plan
  ./scripts/workflow.sh status
EOF
}

case "$#:${1:-}" in
    0:|1:-h|1:--help) usage; exit 0 ;;
esac

mkdir -p .workflow/approvals

hash_file() { ... }
approve_file() { ... }

case "$#:${1:-}" in
    1:approve-plan)         approve_file PROJECT_PLAN.md PROJECT_PLAN; ... ;;
    1:approve-review)       ... ;;
    1:approve-updated-plan) ... ;;
    1:status)                ... ;;
    *)
        usage
        exit 1
        ;;
esac
```

The main `case` keeps its `*)` arm's current text (delegated to the shared
`usage()`), current stdout stream, and `exit 1` — unchanged per BH-15. The
early-exit case and the main case together mean: empty/`-h`/`--help` → usage,
exit 0, no `mkdir -p`; a recognized subcommand with no extra args → unchanged
behavior; anything else (unknown subcommand, or a recognized subcommand plus
trailing args) → usage, exit 1, but only *after* `mkdir -p` has already run —
this matches current behavior exactly, since today's `*)` path also runs after
line 7. Only the help/empty path moves ahead of the side effect.

`from-issue.sh`: no source change (BH-16 PRESERVE) — unaffected by AR-001
since its `usage()`/exit-0 check already runs at line 26, before any
side-effecting statement.

Convention table (extends CHANGE_PLAN §1, resolving Q-1 / AR-002):

| Decision | Value | Reason |
|---|---|---|
| Help stream / exit | stdout, `exit 0` | Spec §4; matches `from-issue.sh` (IV-04) |
| Unknown-arg stream (`stagegate.sh`, `change-workflow.sh`, `codex-review-plan.sh`, `codex-create-checklist.sh`) | stderr | Spec §4, scoped to the four scripts newly guarded in this change |
| Unknown-arg stream (`workflow.sh` `*)`, all of `from-issue.sh`) | stdout | BH-15/BH-16 PRESERVE — explicit exception to the stderr rule above; not a spec violation, a scoping clarification (AR-002) |
| Unknown-arg exit code | `1` | Repo already uses 1 for this; BH-15 requires 1 |
| Version string | literal `STAGEGATE_VERSION="0.1.0"` in each of the two drivers | Spec §13 default; no `VERSION` file (Q-2, unresolved, deferred — see §20) |
| Guard inspects | `$1` **and** `$#` | AR-005: a recognized flag with trailing arguments (`--help extra`) must reject, not silently accept |

## 2. Alternative approaches considered

Unchanged from CHANGE_PLAN.md § 2.

## 3. Why the selected approach is preferred

Unchanged from CHANGE_PLAN.md § 3.

## 4. Exact components to modify

| File | Insertion point | Change |
|---|---|---|
| `scripts/stagegate.sh` | after `cd "$ROOT"` (line 5), before `STATE_DIR=` (line 7) | version literal, `usage()`, `$#:$1` guard with `--version` |
| `scripts/change-workflow.sh` | after `cd "$ROOT"` (line 5), before `STATE_DIR=` (line 7) | same |
| `scripts/codex-review-plan.sh` | after `cd "$ROOT"` (line 5), before `test -s REQUIREMENTS.md` (line 7) | `usage()`, `$#:$1` guard, no `--version` |
| `scripts/codex-create-checklist.sh` | same | same |
| `scripts/workflow.sh` | **revised (AR-001):** `usage()` defined immediately after `cd "$ROOT"` (line 5); new early-exit `case` for `0:\|1:-h\|1:--help` inserted **before** `mkdir -p .workflow/approvals` (line 7); existing full `case` (now keyed on `$#:$1`) retained below, `*)` arm calls the shared `usage()` and keeps `exit 1` | help/empty now precedes the side effect; subcommand dispatch behavior unchanged |
| `scripts/README.md` | new file | Invocation reference for all six scripts |
| `README.md` (OPTIONAL, OPT-01) | "Manual helpers" section | One-line pointer to `scripts/README.md` |

Verified before planning: no `usage` function or `VERSION` identifier exists in
any script except `from-issue.sh:7`, so no name collision is introduced.
`workflow.sh:7`'s `mkdir -p` is the only side-effecting statement preceding
dispatch in that file (confirmed by re-reading `scripts/workflow.sh:1-37`).

## 5. Components explicitly not to modify

Unchanged from CHANGE_PLAN.md § 5, with one addition: `workflow.sh`'s
`approve_file`/`hash_file` function bodies and the four dispatch branches'
internal logic are untouched — only the `case` key changes from `"${1:-}"` to
`"$#:${1:-}"` and the help/empty arm moves above `mkdir -p`.

## 6. Data-flow changes

Revised from CHANGE_PLAN.md § 6 to reflect the `$#` discrimination and the
`workflow.sh` reordering:

One new early-exit path per modified script: `($# , argv[1]) → case → (usage →
stdout → exit 0) | (version → stdout → exit 0) | (anything else → unknown →
stream per §1 → exit 1) | (0 args → fall through to existing flow)`. For
`workflow.sh` specifically, the help/empty branch is evaluated and can exit
*before* `mkdir -p .workflow/approvals` runs; every other path (recognized
subcommand, unknown subcommand) reaches `mkdir -p` exactly as it does today.
No existing data flow is rerouted for the four other guarded scripts; their
zero-argument case reaches the original first statement with identical state.

Newly reachable-before: nothing. Newly unreachable on the help/version/unknown
paths: `mkdir -p` (both drivers **and now `workflow.sh`**), `WORKFLOW_*` reads,
`test -s` preconditions (both `codex-*` scripts), all `claude`/`codex`
invocation, the state-machine loop.

## 7. Pre-implementation checks

1. Confirm the human approval of this document explicitly reaffirms the IV-03
   relaxation (`workflow.sh` no-arg/`-h`/`--help` moving from exit 1 to exit
   0). If the approval record does not address this specifically, implement
   only `-h`/`--help` → exit 0 for `workflow.sh` and leave bare no-args at
   exit 1; record this as a deviation in `IMPLEMENTATION_NOTES.md` (AR-003).
2. Capture golden fixtures (AR-009) before editing any file: run and save
   stdout, stderr, and exit status for `workflow.sh status`, `workflow.sh
   bogus-subcommand`, and `from-issue.sh --help` / `-h` / no-args, all against
   the current (pre-change) tree.
3. Confirm the §11 containment fixture will be a `git worktree`, not a `cp
   -R` copy (AR-007), and that it starts with no `.workflow` directory.
4. Re-confirm no in-repo caller passes arguments to any of the six scripts
   (CHANGE_PLAN §8 finding still holds; re-grep `scripts/` before editing
   `change-workflow.sh`'s `run_codex`).

## 8. Post-implementation checks

1. Run T-01 through T-14 (§12) in full; none may be marked passed without
   execution (Core rule 10).
2. Diff every "byte-identical" claim (T-08, T-09, T-10) against the golden
   fixtures captured in §7 step 2 with `cmp`, not against BASELINE_REPORT
   prose (AR-009).
3. For every help/version/unknown-argument invocation of `workflow.sh`
   specifically, assert `.workflow/approvals` was not created (AR-001) —
   this is the one path where "no `.workflow` mutation" was previously
   unverified.
4. Run MC-01 through MC-08 (§14).
5. Confirm no `claude`/`codex` process was invoked and no cost-ledger file
   grew during any T-01..T-14 run (MC-06).

## 9. Exact acceptance criteria

Restates CHANGE_SPEC §5 verbatim, annotated where a finding sharpens the
check:

- AC-01: `stagegate.sh --help`/`-h` → usage on stdout, exit 0, no `.workflow/`
  mutation, no `claude`/`codex` call. **Annotated:** `--help extra` (two
  args) must instead hit the unknown-argument path (AR-005).
- AC-02: `stagegate.sh --version` → `0.1.0`, exit 0.
- AC-03: `change-workflow.sh --help`/`-h`/`--version` → same as AC-01/AC-02.
- AC-04: `stagegate.sh --bogus` / `change-workflow.sh --bogus` → usage on
  stderr, exit non-zero, no side effects.
- AC-05: `codex-review-plan.sh --help` and `codex-create-checklist.sh --help`
  → usage text, exit 0, no precondition-file check performed. **Annotated:**
  each script's usage text must name that script by basename, not the other's
  (AR-008); both scripts must also be covered by an unknown-argument case
  (AR-008 extends T-06).
- AC-06: `workflow.sh` no-args/`-h`/`--help` → usage, exit 0, **and no
  `.workflow/approvals` directory created (AR-001, new clause)**.
  `workflow.sh status` and the four `approve-*` subcommands are
  byte-identical to current behavior (verified against the §7 golden
  fixtures, not prose — AR-009).
- AC-07: `from-issue.sh --help`/`-h`/no-args → unchanged (usage, exit 0),
  verified against golden fixtures (AR-009).
- AC-08: `scripts/README.md` exists and documents invocation syntax for all
  six scripts, cross-checked to actually match each script's `usage()` text
  (AR-008).
- AC-09: No existing zero-argument invocation of any of the six scripts
  changes behavior — **now actually exercised by T-14 (AR-006)**, not merely
  asserted by absence of filesystem change.

## 10. Conditions that require stopping implementation

- The human approval of this document does not explicitly address the IV-03
  relaxation → implement the narrower `workflow.sh` change only (§7 step 1),
  do not proceed to the exit-0-for-bare-no-args behavior without a follow-up
  approval.
- Any golden-fixture diff (§7 step 2, §8 step 2) shows a mismatch on
  `workflow.sh status`, `workflow.sh bogus-subcommand`, or any `from-issue.sh`
  preserved form → stop, do not weaken the test, investigate the diff.
- The AR-007 containment check (`test ! -e .workflow` before every
  invocation) ever finds `.workflow` already present in the worktree fixture
  → the fixture is contaminated; stop and rebuild it, do not proceed on a
  dirty fixture.
- Any T-01..T-14 run observes an actual `claude` or `codex` process spawned,
  or the cost ledger grows → stop immediately; a guard is falling through.
- MC-01 finds any guard placed after a side-effecting statement in any of
  the five modified scripts (this is precisely what AR-001 found once) →
  stop and fix the insertion point before continuing to the next script in
  the sequence.

## 11. Feature-flag and containment strategy

Revised from CHANGE_PLAN.md § 11 for AR-007. No feature flag (unchanged
reasoning).

Containment applies to **verification**, which is the risky part.
BASELINE_REPORT §11 declined to execute the two drivers because a fall-through
starts a real, billed run. Verification of AC-01..AC-04 and the new T-14 must
run under all three of:

1. **A clean `git worktree`**, not a `cp -R` copy: `git worktree add --detach
   <tmp> HEAD`. A worktree checkout contains no gitignored content (no
   pre-existing `.workflow/`), unlike a filesystem copy of the working tree —
   this directly fixes AR-007, where a `cp -R` fixture could carry this
   repo's real `.workflow/` directory and mask a mutation from both the
   creation check and `git status`.
2. `WORKFLOW_AGENT_CMD=false WORKFLOW_REVIEWER_CMD=false` exported, so any
   fall-through cannot invoke `claude` or `codex` and dies immediately under
   `set -e` with no spend.
3. Before and after every invocation in the fixture, assert absence directly:
   `test ! -e .workflow` (or `find .workflow` expected to error/return
   nothing) — not `git status --porcelain`, which cannot see a gitignored
   directory at all (AR-007's core point).

## 12. Automated-test strategy

Retains CHANGE_PLAN §12's table with T-04, T-05, T-06, T-11 revised and T-14
added; T-01, T-02, T-03, T-07, T-08, T-09, T-10, T-12, T-13 unchanged in
substance (T-13 now runs inside the §11 worktree fixture).

| ID | Command | Expected |
|---|---|---|
| T-01 | `stagegate.sh --help`; `-h` | usage on stdout, exit 0, no `.workflow/` created |
| T-02 | `stagegate.sh --version` | `0.1.0`, exit 0 |
| T-03 | `change-workflow.sh --help`; `-h`; `--version` | as T-01/T-02 |
| T-04 (revised, AR-005) | `stagegate.sh --bogus`; `stagegate.sh --help extra`; `change-workflow.sh --bogus`; `change-workflow.sh --version extra` | usage on stderr, exit 1, no `.workflow/` created — trailing-argument forms now included, not just a single unrecognized flag |
| T-05 (revised, AR-008) | `codex-review-plan.sh --help`; `-h`; and same for `codex-create-checklist.sh` | usage on stdout, exit 0, no precondition failure; **each output must contain that script's own basename and must not contain the other script's basename** |
| T-06 (revised, AR-008) | `codex-review-plan.sh --bogus`; `codex-create-checklist.sh --bogus` (previously only the first) | usage on stderr, exit 1, both scripts covered |
| T-07 | `workflow.sh`; `-h`; `--help` | usage on stdout, exit 0 (was exit 1); **and `.workflow/approvals` not created (AR-001)** |
| T-08 | `workflow.sh status` | byte-identical via `cmp` to the §7 golden fixture (AR-009), exit 0 |
| T-09 | `workflow.sh bogus-subcommand` | byte-identical via `cmp` to the §7 golden fixture, usage on stdout, exit 1 — unchanged |
| T-10 | `from-issue.sh --help`; `-h`; no args | byte-identical via `cmp` to the §7 golden fixtures, exit 0 |
| T-11 (revised, AR-004) | `for f in scripts/*.sh; do bash -n "$f" \|\| exit 1; done` | exit 0 for all six scripts individually checked |
| T-12 (revised, AR-008) | `test -s scripts/README.md`; read-through against §4 invocation syntax; grep each script's own usage-text keywords appear in its README entry | exit 0, all six scripts documented and matching their actual `usage()` text |
| T-13 | `git status --porcelain` before/after T-01..T-11 in the worktree fixture | no tracked-file change from any help/version/unknown invocation (supplementary to T-01/T-04/T-07's direct `.workflow` absence checks, not a replacement for them — AR-007) |
| T-14 (new, AR-006) | Zero-argument invocation of `stagegate.sh`, `change-workflow.sh` (both with `WORKFLOW_*_CMD=false`), `codex-review-plan.sh`, `codex-create-checklist.sh` (both against the same precondition-file fixture used in BASELINE_REPORT §9), each run once on a pre-change worktree and once on the post-change worktree | stdout, stderr (up to the stubbed-command failure point), and exit status identical between pre- and post-change runs |

Alternative considered and rejected: adding `tests/help_test.sh`. Unchanged
reasoning from CHANGE_PLAN §12.

## 13. Regression-test strategy

Revised from CHANGE_PLAN.md § 13: the byte-identical checks (T-08, T-09, T-10)
now compare against captured golden fixtures (§7 step 2, `cmp`-verified), not
against BASELINE_REPORT §9 prose (AR-009) — the prior plan's language "must
produce output identical to BASELINE_REPORT §9" is retired; BASELINE_REPORT
remains the *reason* these are regression guards, not the comparison operand.

T-05, T-07 remain the primary "was broken, now fixed" regression checks
(`codex-*` `--help` producing no output today; `workflow.sh --help` exiting 1
today). T-14 is a new regression guard specific to AC-09 (AR-006): it is the
first check in either plan that actually exercises the zero-argument
preserved path rather than inferring its preservation from the absence of a
filesystem change on the flag paths.

T-11 guards IV-06 (bash 3.2 parse) and, as revised, actually checks all six
files rather than one (AR-004). T-13 guards IV-07 alongside T-01/T-04/T-07's
direct `.workflow`-absence assertions, not in place of them (AR-007).

## 14. Manual-verification strategy

Retains CHANGE_PLAN §14's MC-01..MC-06, revised/added as follows:

| ID | Check |
|---|---|
| MC-01 (revised) | Read the diff: every guard sits after `cd "$ROOT"` and before the first side-effecting statement in its file — for `workflow.sh` specifically, confirm the help/empty case precedes `mkdir -p .workflow/approvals` at (shifted) line 7, not merely the main dispatch `case` (AR-001) |
| MC-02 | Read the diff: `set -euo pipefail` and lines 1–5 unmodified in all six scripts (IV-01, IV-02) |
| MC-03 | Read the guards for bash 3.2 constructs only — no associative arrays, no `${var^^}`, no regex (IV-06); confirmed executable by T-11 |
| MC-04 | Read the diff: no new `WORKFLOW_*` read and no configuration flag added (IV-05) |
| MC-05 | Cross-read `scripts/README.md` against each script's actual arguments and each `usage()` text — no documented flag that does not exist, no flag that is not documented, no cross-script copy-paste (AC-08, AR-008) |
| MC-06 | Confirm the worktree containment of §11 was actually used for T-01..T-06 and T-14, and that `claude`/`codex` were never invoked (no cost-ledger or log growth) |
| MC-07 (new, AR-005) | Read the diff: every guard's `case` keys on `"$#:${1:-}"`, not `"${1:-}"` alone, so a recognized flag with trailing arguments falls to the unknown-argument arm |
| MC-08 (new, AR-002/Q-1) | Confirm `workflow.sh`'s `*)` arm and all of `from-issue.sh` still write to stdout on unknown input, and that this is documented in `scripts/README.md` as an intentional exception to the stderr convention, not an oversight |

A reviewer-authored `MANUAL_CHECKLIST.md` supersedes this list where they
conflict.

## 15. Observability changes

Unchanged from CHANGE_PLAN.md § 15.

## 16. Implementation sequence

Revised from CHANGE_PLAN.md § 16 to add the golden-fixture capture (AR-009)
as a new first step and to reorder `workflow.sh` work around the `mkdir -p`
fix (AR-001):

0. **(New)** Capture golden fixtures: `workflow.sh status`, `workflow.sh
   bogus-subcommand`, `from-issue.sh --help`/`-h`/no-args — save stdout,
   stderr, exit status to temp files before editing any script.
1. `scripts/codex-review-plan.sh` — guard, `$#:$1` keyed (IV-08). Lowest
   blast radius; establishes the block the other files copy.
2. `scripts/codex-create-checklist.sh` — same guard, with its own
   basename-correct usage text (AR-008 — do not copy-paste from step 1
   without editing the script name).
3. `scripts/workflow.sh` — extract `usage()`; insert the help/empty
   early-exit **before** `mkdir -p` (AR-001, the change from CHANGE_PLAN's
   original sequencing); leave the main `case` keyed on `"$#:${1:-}"` with
   `*)` semantics intact per BH-15.
4. Run T-05..T-09, T-11, T-13 in place (safe to execute directly: no agent
   invocation on these paths).
5. `scripts/stagegate.sh` — version literal + `$#:$1` guard (IV-07). Highest
   blast radius; done after the pattern is proven.
6. `scripts/change-workflow.sh` — same.
7. Set up the §11 worktree containment, run T-01..T-04, T-11, T-13, T-14.
8. `scripts/README.md` — write from the finished `usage()` texts so the two
   cannot disagree; run T-12, MC-05.
9. Record deviations in `IMPLEMENTATION_NOTES.md` (including the §7/§10
   IV-03 disposition, whichever branch was taken), results in
   `CHANGE_TEST_REPORT.md`.
10. OPT-01 (`README.md` pointer) last, only if steps 0–9 are clean.

## 17. Scope cuts under time pressure

Unchanged from CHANGE_PLAN.md § 17. The AR-001 `mkdir -p` reorder and the
AR-005 `$#` check are not on this list and may not be cut: both are
correctness fixes to behavior CHANGE_SPEC §4/§9 already require, not new
scope.

## 18. Change-impact table

Retains CHANGE_PLAN §18 with `workflow.sh`'s row revised for AR-001:

| Component | Planned change | Reason | Regression risk | Test coverage |
|---|---|---|---|---|
| `scripts/stagegate.sh` | Insert version literal, `usage()`, `$#:$1` guard at line 6 | BH-01/02/03, AC-01/02/04, IV-07 | Medium — 594-line driver, real spend on fall-through; mitigated by the `0:` branch and §11 containment | T-01, T-02, T-04, T-11, T-13, T-14; MC-01..MC-04, MC-07 |
| `scripts/change-workflow.sh` | Same | BH-05/06/07, AC-03/04, IV-07 | Medium — as above, plus cost ledger downstream | T-03, T-04, T-11, T-13, T-14; MC-01..MC-04, MC-07 |
| `scripts/codex-review-plan.sh` | Insert `usage()` + guard above the `test -s` block | BH-09, AC-05, IV-08 | Low — 73 lines, no in-repo caller, zero-arg path untouched | T-05, T-06, T-11, T-14; MC-01, MC-07, MC-08 |
| `scripts/codex-create-checklist.sh` | Same | BH-11, AC-05, IV-08 | Low — as above | T-05, T-06, T-11, T-14; MC-01, MC-07, MC-08 |
| `scripts/workflow.sh` | Extract `usage()`; insert help/empty early-exit **before `mkdir -p`**; retain main `case` (now `$#:$1` keyed) unchanged below | BH-13, AC-06, IV-03 (RELAXED), IV-07 (newly applies here per AR-001) | **Raised to High** — the only file where a misplaced guard was already caught creating an unintended side effect (AR-001); a mis-ordered branch could also swallow `status`/`approve-*` | T-07, T-08, T-09, T-11, T-14; MC-01, MC-02, MC-08 |
| `scripts/from-issue.sh` | None | BH-16 PRESERVE | None | T-10 |
| `scripts/README.md` | New file | BH-17, AC-08 | None (new file) | T-12, MC-05 |
| `README.md` | OPT-01: one-line pointer (optional, first cut) | CONTRIBUTING.md doc convention | None | MC-05 |

## 19. Traceability

Retains CHANGE_PLAN §19 with rows updated for the added tests/checks:

| Requirement | Behavior | Invariant | Component | Automated test | Manual check |
|---|---|---|---|---|---|
| AC-01 | BH-01 | IV-07, IV-02 | `stagegate.sh` | T-01, T-04, T-13, T-14 | MC-01, MC-06, MC-07 |
| AC-02 | BH-02 | IV-05 | `stagegate.sh` | T-02 | MC-04 |
| AC-03 | BH-05, BH-06 | IV-07, IV-02 | `change-workflow.sh` | T-03, T-04, T-13, T-14 | MC-01, MC-06, MC-07 |
| AC-04 | BH-03, BH-07 | IV-07 | both drivers | T-04, T-13 | MC-01, MC-06, MC-07 |
| AC-05 | BH-09, BH-11, BH-10, BH-12 | IV-08 | both `codex-*` scripts | T-05, T-06, T-14 | MC-01, MC-07, MC-08 |
| AC-06 | BH-13, BH-14, BH-15 | IV-03 (RELAXED) | `workflow.sh` | T-07, T-08, T-09 | MC-01, MC-02, MC-08 |
| AC-07 | BH-16 | IV-04 | `from-issue.sh` | T-10 | MC-08 |
| AC-08 | BH-17 | — | `scripts/README.md` | T-12 | MC-05 |
| AC-09 | BH-04, BH-08 | IV-05 | both drivers | T-13, T-14 | MC-04 |
| Spec §4 (bash 3.2) | all | IV-06 | all modified scripts | T-11 | MC-03 |
| Spec §4 (`set -euo pipefail`, `cd "$ROOT"` first) | all | IV-01, IV-02 | all modified scripts | T-11 | MC-02 |
| Spec §4 (no side effect before dispatch, all six scripts) | all | IV-07, IV-08 | `workflow.sh` (new), both drivers, both `codex-*` | T-01, T-03, T-05, T-07 | MC-01 |
| Spec §4 (reject any unrecognized argument, incl. trailing) | all | — | five guarded scripts | T-04, T-06 | MC-07 |

## 20. Risks and unresolved questions

Retains CHANGE_PLAN §20's R-1..R-5 and Q-2/Q-3 unchanged. Q-1 is resolved
(see disposition of AR-002 above; superseded, not carried forward). New:

| ID | Item | Disposition |
|---|---|---|
| R-1 | A malformed guard lets `--bogus` fall through on a driver, starting a real billed run during verification | Unchanged from CHANGE_PLAN — mitigated by §11 worktree containment; implementer must not run T-04/T-14 in this working tree first |
| R-2 | `0.1.0` duplicated in two files drifts | Unchanged — accepted for now |
| R-3 | `scripts/README.md` and the `usage()` texts drift apart | Unchanged — mitigated by sequence step 8 and MC-05; AR-008 adds content assertions in T-12 as partial automated coverage |
| R-4 | `workflow.sh` help branch placed after `*)` or matching too broadly would break `status`/`approve-*` | Unchanged — T-08, T-09 are now `cmp`-verified against golden fixtures (AR-009), a stronger check than the prior prose comparison |
| R-5 | Baseline §13's `run_codex`-invokes-`codex-*` claim was already found incorrect; no action needed | Unchanged from CHANGE_PLAN |
| Q-2 | Literal `0.1.0` per driver vs. a shared `VERSION` file | Unchanged — deferred, literal chosen for minimal change surface |
| Q-3 | Exact usage wording is implementer's choice | Unchanged — no action needed, now constrained additionally by AR-008 (must include own basename) |
| R-6 (new) | AR-003: IV-03 relaxation approval may not be explicit even after this document's gate, if the approver focuses on the disposition table rather than §7/§10 | Mitigated by making the check a named, numbered pre-implementation step (§7.1) and a stopping condition (§10), not an implicit assumption |
| R-7 (new) | AR-007's worktree containment leaves a worktree and branch behind if not cleaned up (`git worktree remove`) | Add explicit `git worktree remove <tmp> --force` (or equivalent) at the end of the §11/§16 verification steps; not a correctness risk to the change itself, only local housekeeping |
