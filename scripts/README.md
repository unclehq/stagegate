# scripts/

Six standalone bash scripts. Each resolves the repository root from its own
location and `cd`s there first, so any of them can be run from any working
directory. All are bash 3.2 compatible (macOS system bash).

Every script accepts `-h` / `--help`, prints a usage summary, and exits 0
without performing any other work — no directory creation, no precondition
checks, and no `claude` / `codex` invocation.

## Scripts

### `stagegate.sh` — new-application workflow driver

Runs the human-gated new-application workflow from `REQUIREMENTS.md`. It is a
resumable state machine; re-run it to continue from the current stage.

```sh
./scripts/stagegate.sh              # run / resume the workflow
./scripts/stagegate.sh -h
./scripts/stagegate.sh --help
./scripts/stagegate.sh --version    # prints 0.1.0
```

Takes no positional arguments. All configuration is via `WORKFLOW_*`
environment variables (see [Configuration](#configuration)). Approvals are
recorded with `./scripts/workflow.sh`.

### `change-workflow.sh` — existing-code change workflow driver

Runs the human-gated existing-code change workflow from `CHANGE_REQUEST.md`.
Also a resumable state machine; re-run it to continue from the current stage.

```sh
./scripts/change-workflow.sh              # run / resume the workflow
./scripts/change-workflow.sh -h
./scripts/change-workflow.sh --help
./scripts/change-workflow.sh --version    # prints 0.1.0
```

Takes no positional arguments. All configuration is via `WORKFLOW_*`
environment variables. Seed `CHANGE_REQUEST.md` from a GitHub issue with
`./scripts/from-issue.sh`.

### `workflow.sh` — manual approval helper

Records a human approval by writing the SHA-256 of the approved file to
`.workflow/approvals/`, and reports approval status.

```sh
./scripts/workflow.sh approve-plan
./scripts/workflow.sh approve-review
./scripts/workflow.sh approve-updated-plan
./scripts/workflow.sh status
./scripts/workflow.sh -h
./scripts/workflow.sh --help
```

Exactly one subcommand is required. `-h` / `--help` print the usage block and
exit 0. Any other input — no arguments, an unknown subcommand, or a valid
subcommand with extra arguments — prints the same usage block and exits 1.

### `from-issue.sh` — seed a workflow from a GitHub issue

Fetches a GitHub issue and writes `CHANGE_REQUEST.md` or the project-brief
section of `REQUIREMENTS.md` from it.

```sh
./scripts/from-issue.sh <issue-number | github-url> [--change | --new]
./scripts/from-issue.sh 123
./scripts/from-issue.sh https://github.com/owner/repo/issues/123 --new
./scripts/from-issue.sh -h
./scripts/from-issue.sh --help
./scripts/from-issue.sh                   # no arguments: same as --help
```

- `--change` writes `CHANGE_REQUEST.md` (the default if `CHANGE_REQUEST.md`
  already exists or the repo is not empty), then prompts for the exact word
  `RUN` and, on confirmation, runs `./scripts/change-workflow.sh` in the same
  process. Anything other than `RUN`, including EOF, is a decline: the file
  stays, nothing runs, exit 0. The prompt is printed and blocks even when stdin
  is not a terminal.
- `--new` replaces the project-brief section of `REQUIREMENTS.md` for
  `./scripts/stagegate.sh`. Unchanged: no prompt, no auto-run, no close.

Requires either the `gh` CLI (authenticated) or `curl` (public repos only).
Closing the issue additionally requires `gh`: if the issue was fetched over the
`curl` fallback, or `gh` is missing or unauthenticated at close time, the close
is skipped with a message and the run is still a success.

After a confirmed run exits 0, the issue is closed only if all of these hold:
`.workflow/audit-verdict` records this run's id, its verdict class is `READY` or
`READY_WITH_NON_BLOCKING_ISSUES`, `.workflow/origin` still names this issue, and
`FINAL_AUDIT.md` still hashes to the value recorded when it was classified. Any
mismatch leaves the issue open and prints the reason. A driver exit code other
than 0 is propagated and no close is attempted.

State files this contract depends on, all under the gitignored `.workflow/`:

| File | Written by | Meaning |
|---|---|---|
| `origin` | `from-issue.sh` on confirmation; `change-workflow.sh` in `ANALYZE` | `<owner/repo>TAB<issue>` that owns this checkout's in-flight run |
| `audit-verdict` | `change-workflow.sh` in `FINAL_AUDIT` | `<run-id>TAB<class>TAB<sha256 of FINAL_AUDIT.md>` |
| `lock/pid` | `change-workflow.sh` for the length of a run | pid of the run holding the checkout |

`from-issue.sh --change` refuses to seed when `.workflow/state` shows an
in-flight run whose `.workflow/origin` names a different issue, or names nothing
at all. When the origin matches the issue being seeded, `CHANGE_REQUEST.md` is
left as it is — hand edits survive a resume — and only the prompt is repeated.
`change-workflow.sh` performs the mirror-image check when launched by
`from-issue.sh`, and refuses to start at all while another run holds
`.workflow/lock`.

### `codex-review-plan.sh` — adversarial plan review (Stage 2)

Runs the reviewer CLI against the approved `PROJECT_PLAN.md` and writes
`ADVERSARIAL_REVIEW.md`.

```sh
./scripts/codex-review-plan.sh
./scripts/codex-review-plan.sh -h
./scripts/codex-review-plan.sh --help
```

Takes no positional arguments. Requires `REQUIREMENTS.md`, `PROJECT_PLAN.md`,
and a matching approval record in `.workflow/approvals/PROJECT_PLAN.sha256`.
Normally invoked by the driver; can be run by hand.

### `codex-create-checklist.sh` — manual checklist generation (Stage 6)

Runs the reviewer CLI against the approved `UPDATED_PROJECT_PLAN.md` and the
automated-test report, and writes `MANUAL_CHECKLIST.md`.

```sh
./scripts/codex-create-checklist.sh
./scripts/codex-create-checklist.sh -h
./scripts/codex-create-checklist.sh --help
```

Takes no positional arguments. Requires `REQUIREMENTS.md`,
`UPDATED_PROJECT_PLAN.md`, `AUTOMATED_TEST_REPORT.md`, and a matching approval
record in `.workflow/approvals/UPDATED_PROJECT_PLAN.sha256`. Normally invoked
by the driver; can be run by hand.

## Argument handling summary

| Script | `-h` / `--help` | `--version` | Positional arguments | Unrecognized argument |
|---|---|---|---|---|
| `stagegate.sh` | usage, exit 0 | `0.1.0`, exit 0 | none | usage on **stderr**, exit 1 |
| `change-workflow.sh` | usage, exit 0 | `0.1.0`, exit 0 | none | usage on **stderr**, exit 1 |
| `codex-review-plan.sh` | usage, exit 0 | not supported | none | usage on **stderr**, exit 1 |
| `codex-create-checklist.sh` | usage, exit 0 | not supported | none | usage on **stderr**, exit 1 |
| `workflow.sh` | usage, exit 0 | not supported | exactly one subcommand | usage on **stdout**, exit 1 |
| `from-issue.sh` | usage, exit 0 | not supported | issue number or URL, optional `--change` / `--new` | usage on **stdout**, exit 1 |

Two intentional exceptions to the "unrecognized argument goes to stderr" rule:
`workflow.sh`'s fall-through branch and all of `from-issue.sh` write usage to
**stdout**. Both are pre-existing behaviors that callers may depend on, and
both are deliberately preserved rather than made uniform.

A recognized flag with trailing arguments (for example
`./scripts/stagegate.sh --help extra`) is rejected as an unrecognized
argument; it is not silently accepted.

## Configuration

`stagegate.sh`, `change-workflow.sh`, and the two `codex-*` helpers read all
configuration from `WORKFLOW_*` environment variables, never from CLI flags.
The full list of variables, with defaults, is in the top-level `README.md`
under "Configuration". The two that decide which external CLI is spawned:

| Variable | Default | Used by |
|---|---|---|
| `WORKFLOW_AGENT_CMD` | `claude` | `stagegate.sh`, `change-workflow.sh` |
| `WORKFLOW_REVIEWER_CMD` | `codex` | both drivers and both `codex-*` helpers |

Setting both to `false` is a convenient way to exercise the argument-handling
paths without spawning a real agent.
