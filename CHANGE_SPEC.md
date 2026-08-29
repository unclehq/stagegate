# Change Spec

Omitted sections: Performance requirements (no perf-sensitive path touched); Migration requirements (no persisted schema/data format changes); Prototype-isolation requirements (not a prototype).

## 1. Change type

Feature.

## 2. Problem statement

`from-issue.sh` seeds `CHANGE_REQUEST.md`/`REQUIREMENTS.md` from a GitHub
issue but never runs the driver script, and nothing in the repo ever closes
the seeding issue (BASELINE §4, I-05, I-06). The user wants the seed step to
chain into the change workflow and, once that workflow reaches a
satisfactory completion, close the originating issue.

## 3. Current behavior

See BASELINE §4. Summary: `from-issue.sh` writes the seed file, prints a
"Run: ..." hint, exits. `change-workflow.sh`'s `COMPLETE` state always exits
0 regardless of `FINAL_AUDIT.md` verdict (I-06). No code anywhere calls `gh
issue close`.

## 4. Desired behavior

- Scope: `--change` path only (`from-issue.sh` → `change-workflow.sh`). The
  `--new` path (`stagegate.sh`) is unaffected — Motivation text says "change
  workflow" and "completes change-request" specifically (BASELINE §15).
- `from-issue.sh --change`, after writing `CHANGE_REQUEST.md`, invokes
  `./scripts/change-workflow.sh` in the same process instead of only
  printing the hint.
- `change-workflow.sh` must expose a machine-readable completion signal
  distinguishing a `READY`/`READY WITH NON-BLOCKING ISSUES` `FINAL_AUDIT.md`
  verdict from `NOT READY` (I-06 today collapses both to exit 0).
- The issue is closed **only** when the workflow reaches `COMPLETE` with a
  `READY` or `READY WITH NON-BLOCKING ISSUES` verdict. A `NOT READY` verdict,
  or any non-`COMPLETE` exit (human rejection, error, budget exhaustion),
  leaves the issue open.
- Issue close requires `gh` (authenticated, `repo` scope). If only the
  `curl`-fallback fetch path was used (no `gh`), skip the close and print an
  explicit message — never silently no-op and never fail the whole run for
  it.
- The close action posts a comment referencing the completed change (at
  minimum: a pointer to `FINAL_AUDIT.md`'s verdict) before/while closing —
  not a silent close — so the audit trail is visible on GitHub.
- I-07 tension (BASELINE §16): the human-editing window between "seed" and
  "run driver" must be preserved. Resolution: `from-issue.sh` prints the
  populated `CHANGE_REQUEST.md` and requires an explicit interactive
  confirmation before invoking `change-workflow.sh`. This reuses the
  existing `human_gate`-style exact-word confirmation pattern (I-01) rather
  than inventing a new one. A `--yes`/non-interactive flag is out of scope
  (see §16 non-goals) unless CHANGE_PLAN finds it necessary for automation
  callers.

## 5. Acceptance criteria

1. Running `from-issue.sh <issue> --change` seeds `CHANGE_REQUEST.md`, then
   prompts for confirmation, then (on confirmation) runs
   `change-workflow.sh` to completion in the same invocation.
2. Declining the confirmation prompt leaves `CHANGE_REQUEST.md` written but
   does not invoke `change-workflow.sh`, and does not touch the GitHub
   issue.
3. If `change-workflow.sh` reaches `COMPLETE` with `FINAL_AUDIT.md` verdict
   `READY` or `READY WITH NON-BLOCKING ISSUES`, the originating issue is
   closed with a comment, and `gh issue view <n> --jq .state` reports
   `CLOSED`.
4. If the verdict is `NOT READY`, or the workflow does not reach
   `COMPLETE`, the issue remains open.
5. If the issue was fetched via the `curl` fallback (no authenticated
   `gh`), the run never attempts a close and prints a message explaining
   why.
6. `--new` path behavior (`stagegate.sh`) is byte-for-byte unchanged.
7. All six scripts still pass `bash -n`; the documented
   help/version/unknown-arg contract (`scripts/README.md:115-129`) is
   unchanged for all scripts' existing flags.

## 6. Observable behavior table

| ID | Class | Trigger | Current behavior | Expected behavior | Verification |
|---|---|---|---|---|---|
| B-01 | MODIFY | `from-issue.sh <issue> --change` completes writing `CHANGE_REQUEST.md` | prints "Run: ./scripts/change-workflow.sh" hint, exits | prints seeded file, prompts for exact-word confirmation | manual run |
| B-02 | ADD | user confirms at the new prompt | n/a | invokes `./scripts/change-workflow.sh` in-process, streams its output | manual run |
| B-03 | ADD | user declines/aborts the new prompt | n/a | exits without invoking the driver or GitHub; `CHANGE_REQUEST.md` remains on disk as written | manual run |
| B-04 | ADD | `change-workflow.sh` reaches `COMPLETE`; `FINAL_AUDIT.md` verdict is `READY`/`READY WITH NON-BLOCKING ISSUES` | n/a (no close exists today) | issue closed via `gh issue close --comment` | `gh issue view <n> --jq .state` == `CLOSED`; comment present |
| B-05 | ADD | `change-workflow.sh` reaches `COMPLETE`; verdict is `NOT READY` | n/a | issue left open; message printed explaining why | `gh issue view <n> --jq .state` == `OPEN` |
| B-06 | ADD | workflow run ends in a non-`COMPLETE` state (rejection, error, budget stop) | n/a | issue left open; no close attempted | manual run / state inspection |
| B-07 | ADD | close is due but only the `curl` fallback path was used to fetch the issue | n/a | close skipped; explicit stderr/stdout message, exit code reflects successful workflow completion (close-skip is not a failure) | manual run with `gh` unauthenticated |
| B-08 | PRESERVE | `from-issue.sh <issue> --new` / `--new` auto-detected | writes `REQUIREMENTS.md` section, prints hint, exits | unchanged — no auto-run, no close | manual run, diff vs current output |
| B-09 | PRESERVE | `from-issue.sh` with no args, `--help`, or unrecognized arg | usage to stdout; exit 0 or 1 per BASELINE §6 | unchanged | `bash -n`; re-run BASELINE §8 commands |
| B-10 | MODIFY | `change-workflow.sh` `COMPLETE` state exit behavior | always `exit 0` regardless of verdict (I-06) | still `exit 0` for a human running it standalone (compat), but now also emits a parseable verdict signal (e.g., a state file or a distinct marker in `.workflow/`) that `from-issue.sh` (or any caller) can read after the process exits | manual run, inspect signal artifact/exit code contract |

## 7. Invariant table

| ID | Status | Invariant | Scope | Enforcement point | Verification |
|---|---|---|---|---|---|
| I-01 | EXISTING | Approval-requiring transitions block on exact-word interactive human response | `change-workflow.sh` internal stages | `human_gate()` | manual |
| I-02 | EXISTING | Approved artifacts are SHA-256 pinned; post-approval edits halt the pipeline | `change-workflow.sh` | `verify_approval()` | manual |
| I-03 | EXISTING | Reviewer-owned files written only via reviewer-CLI call sites | `change-workflow.sh` | state-machine call sites | structural read |
| I-04 | EXISTING | Every script runnable from any CWD | all scripts | `ROOT=...; cd "$ROOT"` | manual |
| I-05 | RELAXED | `from-issue.sh` never mutates GitHub state | `from-issue.sh` (`--change` path only) | new `gh issue close`/`gh issue comment` call, gated on B-04 | manual: verify no close/comment on decline (B-03), `NOT READY` (B-05), non-`COMPLETE` (B-06), or curl-fallback (B-07) |
| I-06 | STRENGTHENED | `change-workflow.sh` `COMPLETE` exit is independent of/decoupled from verdict text | `change-workflow.sh` | `COMPLETE` state | now also emits a machine-readable verdict signal alongside the unchanged `exit 0`; manual run |
| I-07 | STRENGTHENED | A human gets an editing/review window on `CHANGE_REQUEST.md` before the driver runs | `from-issue.sh --change` path | new explicit confirmation prompt (replaces the implicit "user manually re-runs" window with an explicit in-process gate) | manual: decline path (B-03) leaves driver un-invoked |
| I-08 | NEW | An issue is closed only on a `READY`/`READY WITH NON-BLOCKING ISSUES` verdict, never on `NOT READY` or an incomplete run | `from-issue.sh --change` post-workflow step | close logic reads `FINAL_AUDIT.md` verdict (or the new B-10 signal) before calling `gh issue close` | manual: B-04 vs B-05 vs B-06 |
| I-09 | NEW | A close attempt without authenticated `gh` never silently no-ops and never crashes the run | `from-issue.sh --change` post-workflow step | explicit fallback-path check before close | manual: B-07 |

**I-05 is RELAXED** by explicit request (Motivation: "close issue"). Requires
human approval before implementation per CLAUDE.md rule on RELAXED
invariants.

## 8. Compatibility requirements

- `from-issue.sh --new` output and behavior: unchanged (B-08).
- `from-issue.sh` help/version/unknown-arg contract (BASELINE §6, §8):
  unchanged (B-09).
- `change-workflow.sh` standalone CLI contract (`-h`, `--version`, unknown
  arg, exit codes): unchanged. Its `COMPLETE` state still `exit 0`s for a
  human running it directly (B-10) — no behavior change for existing
  standalone callers, only an addition.
- Users who invoke `from-issue.sh --change` non-interactively (e.g. from a
  script) today get the old print-and-exit behavior; under this change they
  will hit the new confirmation prompt and block. This is a deliberate,
  human-approval-required compatibility break for that calling pattern — see
  §16 non-goals re: a `--yes` flag.

## 9. Error and failure behavior

| Condition | Required behavior |
|---|---|
| `gh` not authenticated / missing at close time, but was available at fetch time | treat as B-07 (skip + message), not a hard failure |
| `gh issue close` call fails (network, permissions) | print the error, exit non-zero; do not report the change as incomplete/failed — the workflow itself already completed |
| `change-workflow.sh` invoked from `from-issue.sh` exits non-zero / is interrupted | no close attempted; propagate the failure to the user clearly |
| Confirmation prompt receives EOF/non-exact input | treat as decline (B-03), matching existing `human_gate()` exact-word semantics (I-01) |

## 10. Security requirements

- The new `gh issue close`/`gh issue comment` call is the first
  GitHub-write capability in this codebase (I-05 relaxation) — confine it to
  the single call site gated by the confirmation (I-07) and the verdict
  check (I-08); do not introduce a general-purpose GitHub-write helper.
- No new persisted credentials; reuse the existing `gh` auth session
  (BASELINE §8: already scoped to `repo`).

## 11. Rollback expectations

Revert to current `from-issue.sh`/`change-workflow.sh` behavior (print hint,
no auto-run, no close) by reverting the change's commits — no data
migration or state cleanup required since `.workflow/` state and
`CHANGE_REQUEST.md` formats are unchanged.

## 12. Explicit non-goals

- `--new`/`stagegate.sh` auto-run and auto-close (BASELINE §15) — out of
  scope, `--change` only.
- A `--yes`/non-interactive bypass flag for the new confirmation prompt.
- Any change to `codex-review-plan.sh`, `codex-create-checklist.sh`,
  `workflow.sh`, or `prompts/**` contents (BASELINE §14).
- Closing via the `curl`-only fallback path (no `gh` credential equivalent
  exists or is being added) — always skip with a message (B-07).

## 13. Assumptions and unresolved questions

- ASSUMED: "completes change-request" (Motivation) means `change-workflow.sh`
  reaching `COMPLETE` with a `READY`/`READY WITH NON-BLOCKING ISSUES`
  verdict, not merely reaching `COMPLETE` (I-06 today doesn't distinguish).
  Flagged for explicit approval given it's a RELAXED-invariant (I-05) design
  choice.
- ASSUMED: the confirmation prompt at B-01/I-07 is an acceptable
  reinterpretation of "run automatically" — the request text says
  "automatically," which is in tension with preserving a human edit window.
  Resolution favors CLAUDE.md's "never bypass an approval gate" over literal
  "automatic." Needs explicit human sign-off.
- UNRESOLVED: exact mechanism for the B-10 machine-readable verdict signal
  (new `.workflow/` file vs. exit-code convention vs. parsing
  `FINAL_AUDIT.md` directly from `from-issue.sh`) is left to CHANGE_PLAN —
  this spec fixes the observable contract (I-06/I-08), not the mechanism.
- UNRESOLVED: whether the close comment should link `.workflow/change.diff`,
  quote the audit verdict, or both — left to CHANGE_PLAN; acceptance
  criterion 3 only requires a comment to exist.
