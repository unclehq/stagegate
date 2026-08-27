# Good first issues

Ready-to-copy GitHub issues for new contributors. Each issue includes the file
to touch, the acceptance criteria, and an effort estimate.

---

## Issue 1: Add `--dry-run` to `scripts/from-issue.sh`

**Labels:** `good first issue`, `enhancement`, `cli`

**Description:**

`scripts/from-issue.sh` writes `CHANGE_REQUEST.md` or updates `REQUIREMENTS.md`
immediately. Add a `--dry-run` flag that fetches the issue and prints the
rendered output to stdout without writing any files.

**Files to touch:**

- `scripts/from-issue.sh`

**Acceptance criteria:**

- [ ] `./scripts/from-issue.sh <issue> --change --dry-run` prints the change
      request without creating `CHANGE_REQUEST.md`.
- [ ] `./scripts/from-issue.sh <issue> --new --dry-run` prints the project brief
      without modifying `REQUIREMENTS.md`.
- [ ] Existing behavior is unchanged when `--dry-run` is omitted.
- [ ] The flag is documented in the script's `--help` output.

**Estimated effort:** small (1–2 hours)

---

## Issue 2: Add shell completion for workflow drivers

**Labels:** `good first issue`, `enhancement`, `cli`

**Description:**

Add optional bash and zsh completion scripts for `stagegate.sh`,
`change-workflow.sh`, and `from-issue.sh`. At minimum, complete the available
flags and, for `from-issue.sh`, the `--change`/`--new` options.

**Files to touch:**

- New directory `completions/`
- `README.md` (installation note)

**Acceptance criteria:**

- [ ] `completions/stagegate.bash` and `.zsh` exist.
- [ ] `completions/change-workflow.bash` and `.zsh` exist.
- [ ] `completions/from-issue.bash` and `.zsh` exist.
- [ ] README.md has a one-line instruction for sourcing the completions.

**Estimated effort:** small (2–3 hours)

---

## Issue 3: Validate `CHANGE_REQUEST.md` before `change-workflow.sh` starts

**Labels:** `good first issue`, `enhancement`, `ux`

**Description:**

`change-workflow.sh` currently fails later if `CHANGE_REQUEST.md` is empty or
still contains placeholder text. Add an early validation step that checks for
non-empty required sections and exits with a helpful message before any agent
stage runs.

**Files to touch:**

- `scripts/change-workflow.sh`

**Acceptance criteria:**

- [ ] If `CHANGE_REQUEST.md` is missing or empty, the driver exits with a clear
      error before launching the agent.
- [ ] If required sections (`Summary`, `Desired Behavior`, `Success Criteria`)
      are still empty/placeholder, the driver warns or exits.
- [ ] The validation runs only in the `ANALYZE` state.
- [ ] Existing valid runs are unaffected.

**Estimated effort:** small (2–3 hours)

---

## Issue 4: Add `workflow.sh status` for the change workflow

**Labels:** `good first issue`, `enhancement`, `ux`

**Description:**

`scripts/workflow.sh status` only shows greenfield approvals
(`PROJECT_PLAN`, `ADVERSARIAL_REVIEW`, `UPDATED_PROJECT_PLAN`). Extend it to
also show the change-workflow approvals
(`BASELINE_REPORT`, `CHANGE_SPEC`, `CHANGE_PLAN`, `UPDATED_CHANGE_PLAN`).

**Files to touch:**

- `scripts/workflow.sh`

**Acceptance criteria:**

- [ ] `workflow.sh status` detects whether the current repo is using the
      greenfield or change workflow and shows the relevant approval set.
- [ ] It reports `APPROVED`, `CHANGED AFTER APPROVAL`, or `NOT APPROVED` for
      each relevant artifact.
- [ ] The existing greenfield output is preserved.

**Estimated effort:** small (1–2 hours)

---

## Issue 5: Add a CI smoke test for shell-script syntax

**Labels:** `good first issue`, `testing`, `ci`

**Description:**

Add a GitHub Actions workflow that runs `bash -n` on every `*.sh` file in
`scripts/` on every pull request. This is the cheapest guard against syntax
regressions.

**Files to touch:**

- `.github/workflows/smoke.yml`
- Optionally `README.md` (CI badge)

**Acceptance criteria:**

- [ ] A workflow file exists that checks out the repo and runs
      `for f in scripts/*.sh; do bash -n "$f"; done`.
- [ ] The workflow triggers on `pull_request` and `push` to `main`.
- [ ] A failing `bash -n` causes the check to fail.

**Estimated effort:** small (1–2 hours)

---

## Issue 6: Unify cost-ledger stage names between drivers

**Labels:** `good first issue`, `refactor`, `dx`

**Description:**

`stagegate.sh` records stages as `requirements`, `project-plan`, etc.
`change-workflow.sh` records agent stages as `agent:<name>` and reviewer stages
as `reviewer:<name>`. Make both drivers use consistent, human-readable stage
names in `.workflow/cost.tsv` (or `.workflow/cost.tsv` for the change driver).

**Files to touch:**

- `scripts/stagegate.sh`
- `scripts/change-workflow.sh`

**Acceptance criteria:**

- [ ] Both drivers use the same stage-name format.
- [ ] The change-workflow ledger no longer prepends `agent:` / `reviewer:`
      unless it is the chosen unified format.
- [ ] No functional behavior changes; only the first column of the ledger is
      affected.

**Estimated effort:** small (1–2 hours)

---

## Issue 7: Create GitHub issue templates

**Labels:** `good first issue`, `documentation`, `github`

**Description:**

Add `.github/ISSUE_TEMPLATE/` with a bug-report form and a feature-request
form. Include prompts that match this project's workflow (e.g., "Which driver?",
"What did you expect?", "Reproduction steps").

**Files to touch:**

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/config.yml` (optional: link to Discussions)

**Acceptance criteria:**

- [ ] Opening a new issue shows the two templates.
- [ ] Each template collects enough information to act on.
- [ ] The bug template asks for driver, version, and reproduction steps.

**Estimated effort:** small (1–2 hours)

---

## Issue 8: Document every `WORKFLOW_*` environment variable in one place

**Labels:** `good first issue`, `documentation`

**Description:**

Environment variables are split between `README.md` and the headers of
`stagegate.sh` / `change-workflow.sh`. Create a single reference page
(`docs/environment-variables.md`) that lists every variable, its default, which
driver uses it, and an example override.

**Files to touch:**

- New file `docs/environment-variables.md`
- `README.md` (link to the new page)

**Acceptance criteria:**

- [ ] Every `WORKFLOW_*` variable from both drivers is documented.
- [ ] Defaults and allowed values are accurate.
- [ ] README.md links to the new page.

**Estimated effort:** small (2–3 hours)

---

## Issue 9: Add `--help` and `--version` to the main drivers

**Labels:** `good first issue`, `enhancement`, `cli`

**Description:**

`stagegate.sh` and `change-workflow.sh` currently expect no arguments.
Add `--help` that prints a short usage summary and `--version` that prints the
workflow version (start with `0.1.0`).

**Files to touch:**

- `scripts/stagegate.sh`
- `scripts/change-workflow.sh`

**Acceptance criteria:**

- [ ] `./scripts/stagegate.sh --help` prints usage and exits 0.
- [ ] `./scripts/stagegate.sh --version` prints a version and exits 0.
- [ ] Same for `change-workflow.sh`.
- [ ] Unknown arguments print usage and exit non-zero.

**Estimated effort:** small (1–2 hours)

---

## Issue 10: Add a minimal end-to-end example project

**Labels:** `good first issue`, `documentation`, `examples`

**Description:**

Create `examples/todo-cli/` containing a tiny project brief and the final
artifacts from a hypothetical greenfield run. This gives new users a concrete
reference for what the pipeline produces.

**Files to touch:**

- `examples/todo-cli/REQUIREMENTS.md`
- `examples/todo-cli/PROJECT_PLAN.md`
- `examples/todo-cli/UPDATED_PROJECT_PLAN.md`
- Optional: a minimal source file

**Acceptance criteria:**

- [ ] `examples/todo-cli/` exists with a realistic project brief.
- [ ] It shows what a completed greenfield artifact set looks like.
- [ ] README.md links to the example.

**Estimated effort:** small (2–4 hours)

---

## How to claim one

Comment on the issue you want to work on. If an issue is not yet opened on
GitHub, copy the text above into a new issue and ask to be assigned.
