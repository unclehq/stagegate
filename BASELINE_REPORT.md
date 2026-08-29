# Baseline Report

Omitted sections: none.

## 1. Change-request summary

See `CHANGE_REQUEST.md` (seeded from unclehq/stagegate#2). Two asks: (a)
`from-issue.sh` should trigger the change workflow automatically instead of
just printing the command to run it; (b) once that workflow finishes, the
seeding issue should be closed. All other `CHANGE_REQUEST.md` sections
(Change Type, Observed/Desired Behavior, Reproduction, Constraints, Known
Files, Out of Scope, Success Criteria) are still unfilled template text — see
§15.

## 2. Repository architecture

Six standalone, mutually-independent bash 3.2 scripts in `scripts/`, each
resolving its own root and `cd`-ing there (`ROOT="$(cd "$(dirname
"${BASH_SOURCE[0]}")/.." && pwd)"`):

| Script | Role |
|---|---|
| `stagegate.sh` | new-application state-machine driver (reads `REQUIREMENTS.md`) |
| `change-workflow.sh` | existing-code change state-machine driver (reads `CHANGE_REQUEST.md`) |
| `workflow.sh` | manual approval/status helper |
| `from-issue.sh` | seeds `CHANGE_REQUEST.md` or `REQUIREMENTS.md` from a GitHub issue |
| `codex-review-plan.sh` | standalone re-run of the adversarial-review stage |
| `codex-create-checklist.sh` | standalone re-run of the manual-checklist stage |

`prompts/change/*.md` and `prompts/*.md` hold the per-stage agent prompts;
`.workflow/` (gitignored) holds runtime state: `state`, `approvals/*.sha256`,
`logs/`, `cost.tsv`, `change.diff`. No test framework, no CI (`.github/`
does not exist), no linter config.

## 3. Relevant code paths

| Path | Relevance |
|---|---|
| `scripts/from-issue.sh:131-152` | mode auto-detection (`--change` vs `--new`) |
| `scripts/from-issue.sh:158-208` | `write_change_request` — writes `CHANGE_REQUEST.md`, prints suggested next command, returns |
| `scripts/from-issue.sh:210-298` | `write_new_project_brief` — same shape for the new-app path |
| `scripts/from-issue.sh:300-303` | dispatch, then script exits |
| `scripts/change-workflow.sh:181-233` | `human_gate` — the interactive approval primitive |
| `scripts/change-workflow.sh:507-698` | the state machine itself, `ANALYZE` → `COMPLETE` |
| `scripts/change-workflow.sh:663-690` | `FINAL_AUDIT` and `COMPLETE` states — where a "done" signal would be read/emitted |
| `prompts/change/final-audit.md:56-58` | defines the `READY` / `READY WITH NON-BLOCKING ISSUES` / `NOT READY` verdict vocabulary |
| `README.md:114-133` | documented "Start from a GitHub issue" flow |
| `README.md:99-113` | documented manual change-request flow (fill in `CHANGE_REQUEST.md` *then* run the driver) |
| `scripts/README.md:63-82,115-129` | `from-issue.sh` CLI/exit-code contract |

## 4. Current observable behavior

`from-issue.sh <issue> [--change|--new]` fetches issue metadata (via `gh
issue view`, falling back to `curl` GET for public repos), writes
`CHANGE_REQUEST.md` or the `REQUIREMENTS.md` project-brief section, prints a
"Run: ..." hint, and exits — it never invokes `change-workflow.sh` or
`stagegate.sh` itself (verified: it contains no call to either script or to
`exec`/`system`-style invocation). It never touches the GitHub issue beyond
the initial read; there is no `gh issue close`/`gh issue comment` anywhere in
the repository (only match for "gh issue" is the read at
`from-issue.sh:86`).

`change-workflow.sh`'s `COMPLETE` state (lines 672-690) prints file names to
review and the cost ledger, then unconditionally `exit 0`s — it does not
parse `FINAL_AUDIT.md` for its `READY`/`NOT READY` verdict; that verdict is
free text written by the reviewer CLI for a human to read.

## 5. Existing invariants

| ID | Invariant | Current enforcement | Existing test | Confidence |
|---|---|---|---|---|
| I-01 | Every stage transition requiring approval blocks on an interactive, exact-word human response; nothing bypasses it | `human_gate()`, `change-workflow.sh:181-233` | none automated (CLAUDE.md rule 1 / "Never bypass a human review gate") | High |
| I-02 | An approved artifact is SHA-256 pinned; a post-approval edit halts the pipeline | `verify_approval()`, `change-workflow.sh:155-174` | none automated; documented in `README.md:182-200` | High |
| I-03 | Reviewer-owned files (`ADVERSARIAL_REVIEW.md`, `MANUAL_CHECKLIST.md`, `FINAL_AUDIT.md`) are written only via `run_codex`/`start_codex_bg` | state-machine call sites in `change-workflow.sh` | none automated (structural read) | High |
| I-04 | Every script is runnable from any CWD via self-relative root resolution | `ROOT=...; cd "$ROOT"` at the top of each script | none automated; manually spot-checked in prior cycle | High |
| I-05 | `from-issue.sh` never mutates GitHub state — fetch is read-only (`gh issue view` / `curl GET`) | `from-issue.sh:85-92`, no write call anywhere in the file | none automated | High |
| I-06 | `change-workflow.sh` `COMPLETE` always exits 0, independent of the audit verdict text | `change-workflow.sh:672-690` | none automated | High |
| I-07 | The documented change-request flow gives a human an editing window on `CHANGE_REQUEST.md` before the driver runs (`README.md` step 2 precedes step 4) | procedural (docs), not code-enforced | none | Medium |

I-05 is the invariant this change request asks to relax (add a GitHub write).
I-07 is the invariant potentially at risk from "run the change workflow
automatically" — see §16.

## 6. Current API, schema, and interface contracts

`from-issue.sh` CLI contract (per `scripts/README.md:63-82,115-129`):
positional `<issue-number|github-url>`, optional `--change`/`--new`; usage is
printed to **stdout** in every case. No args or `-h`/`--help` → usage, exit
0; unrecognized issue arg or unknown flag → usage, exit 1. Verified live
(see §8/§9).

`change-workflow.sh` CLI contract: no positional arguments; `-h`/`--help` →
usage to stdout, exit 0; `--version` → `0.1.0`, exit 0; unknown argument →
usage to **stderr**, exit 1. All configuration via `WORKFLOW_*` env vars
(full table in top-level `README.md` "Configuration"; not restated here).
State persists in `.workflow/state` as a single bare state-name string,
defaulting to `ANALYZE` when absent/empty (`get_state()`,
`change-workflow.sh:127-133`).

## 7. Existing automated-test coverage

None (no test framework, no CI). The prior change cycle (issue #1,
`CHANGE_TEST_REPORT.md`) validated purely via `bash -n` syntax checks on all
six scripts and manual invocation of the argument-handling paths
(help/version/unknown-arg) for each script; `shellcheck` was not installed
and is not a repo dependency.

## 8. Exact build and test commands executed

```
for f in scripts/*.sh; do bash -n "$f"; done      # exit 0 for all 6
command -v gh curl jq shellcheck                  # gh, curl, jq present; shellcheck absent
./scripts/from-issue.sh                           # usage to stdout, exit 0
./scripts/from-issue.sh --help                    # usage to stdout, exit 0
./scripts/from-issue.sh abc                       # "Unrecognized issue argument: abc" + usage to stdout, exit 1
./scripts/change-workflow.sh --help               # usage to stdout, exit 0
./scripts/change-workflow.sh --version            # "0.1.0", exit 0
gh auth status                                     # logged in as brianosaurus, token scope includes `repo`
gh api repos/unclehq/stagegate/issues/2 --jq '.state,.title'   # "open", "help and close issues"
git remote -v                                      # origin -> git@github.com:unclehq/stagegate.git
```

## 9. Baseline test results

All commands above passed / behaved exactly as documented in
`scripts/README.md`. No regressions or surprises versus documented behavior.
Confirmed live against the real remote: issue unclehq/stagegate#2 exists,
is open, and its title matches `CHANGE_REQUEST.md`'s Summary line; the local
`gh` session is authenticated with a token that has the `repo` scope
(sufficient to close issues).

## 10. Existing failures, warnings, and flaky behavior

None observed. `shellcheck` absence is pre-existing and unchanged from the
prior cycle. No CI pipeline exists to fail.

## 11. Reproduction result for the reported bug, if applicable

Not applicable — this is a feature request, not a bug. Note:
`CHANGE_REQUEST.md`'s "Change Type" line itself is still the unselected
template (`Feature | Bug Fix | Prototype | ...`); classified here as Feature
based on the Motivation wording.

## 12. Likely change surface

- `scripts/from-issue.sh` — invoke `./scripts/change-workflow.sh` (and/or
  `./scripts/stagegate.sh`, scope-dependent, see §15) after writing the seed
  file; add issue-close logic keyed to that run's outcome.
- `scripts/change-workflow.sh` — possibly needs to expose a machine-readable
  completion signal (exit code and/or the `FINAL_AUDIT.md` verdict) if
  `from-issue.sh` is what performs the close, since today `COMPLETE` gives no
  such signal (I-06).
- `scripts/README.md`, top-level `README.md` — flow documentation ("Start
  from a GitHub issue" section currently describes a two-step manual
  handoff that this change collapses).

## 13. Regression-sensitive components

- `from-issue.sh` mode-resolution and file-writing logic
  (`write_change_request`, `write_new_project_brief`) — must keep working
  standalone/non-auto-run for users who still want to review before running
  the driver (see I-07 tension in §16).
- The six-script argument-handling contract in `scripts/README.md:115-129`
  (help/version/unknown-arg exit codes and stdout-vs-stderr routing) — easy
  to break by adding new flags carelessly.
- `change-workflow.sh`'s human-gate/approval-hash flow (I-01, I-02) — must
  not be weakened or bypassed by the new automatic invocation.

## 14. Areas explicitly outside the change

`stagegate.sh` internals, `codex-review-plan.sh`, `codex-create-checklist.sh`,
`workflow.sh`, and prompt file contents under `prompts/` are not implicated
by the request text and are assumed out of scope pending CHANGE_SPEC
confirmation.

## 15. Unknowns and assumptions

- `CHANGE_REQUEST.md` leaves Change Type, Observed/Desired Behavior,
  Reproduction, Constraints, Known Relevant Files, Out of Scope, and Success
  Criteria as unfilled template text. The change surface above is inferred
  solely from Summary + Motivation.
- Unclear whether "run the change workflow automatically" also covers the
  `--new` path (auto-running `stagegate.sh`), or only `--change`
  (`change-workflow.sh`). Motivation text says "change workflow" and "close
  issue... completes change-request" specifically — read as `--change`-only
  unless CHANGE_SPEC says otherwise.
- Unclear which run outcome should trigger a close: `COMPLETE` is reached
  regardless of whether `FINAL_AUDIT.md` says `READY`, `READY WITH
  NON-BLOCKING ISSUES`, or `NOT READY` (I-06). Closing on any `COMPLETE`
  could close an issue whose change was judged `NOT READY`.
- No file in the repo currently persists which issue (owner/repo/number)
  seeded a given `CHANGE_REQUEST.md` in a machine-readable way — only a
  Markdown link in the file's header (`from-issue.sh:162`). If the close
  step runs in a process separate from `from-issue.sh` (e.g., triggered from
  inside `change-workflow.sh`'s `COMPLETE` state), that identity has to be
  parsed back out or persisted to a new state file.
- Unclear whether closing should also leave a comment (e.g., linking
  `.workflow/change.diff` or the audit verdict) or close silently.
- The `curl`-only fallback path (unauthenticated, public repos) documented
  in `from-issue.sh` cannot close issues; behavior when only `curl` is
  available and a close is requested is undefined by the request.

## 16. Initial risk assessment

- **Approval-gate tension (I-07):** the documented flow puts a human editing
  window between seeding `CHANGE_REQUEST.md` and starting the driver
  (`README.md` step 2 before step 4). `CHANGE_REQUEST.md` in this very repo
  is evidence why that window matters: even after being "seeded," most of
  its sections are still placeholder text. Auto-running the driver
  immediately after seeding risks kicking off a real, budget-consuming
  (`WORKFLOW_BUDGET_*`), multi-stage agent pipeline against an unreviewed,
  templated change request — in tension with CLAUDE.md's "Inspect existing
  code before proposing changes" and the project's core "human-gated"
  premise. This is a design decision for CHANGE_SPEC/CHANGE_PLAN, not
  resolved here.
- **Wrong-outcome close:** closing on any `COMPLETE` rather than gating on
  the `FINAL_AUDIT.md` verdict could close an issue for a change that was
  judged `NOT READY`.
- **Side-effect scope creep:** `from-issue.sh` today is side-effect-limited
  (writes one local file, one read-only network call). Chaining it to
  `change-workflow.sh` changes it into a long-running, real-money-spending,
  now GitHub-write-capable script — a meaningful behavior/trust change worth
  making explicit and constrained rather than implicit.
- **Auth/tooling gap:** the `curl`-only fetch path has no credentialed
  equivalent for closing; a close request in that path will need explicit
  failure/skip behavior rather than a silent no-op.
