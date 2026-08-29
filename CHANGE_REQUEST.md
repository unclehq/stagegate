# Change Request

Seeded from [unclehq/stagegate#3](https://github.com/unclehq/stagegate/issues/3).

## Change Type

Feature | Bug Fix | Prototype | Refactor | Performance | Security | Upgrade

## Summary

change everything to use opus

## Motivation

change all scripts to use kimi in the place of claude sonnet and claude opus. Kimi is a lot cheaper.

Change .workflow/state to prepend the issue number before the state
If scripts/from-issue.sh is run and the issue number in .workflow/state is not the same zero out .workflow/state so we can then run scripts/change-workflow.sh and it will complete properly 

When the change-workflow.sh is complete have it close the issue if it came from a github issue

Make sure to remove .workflow/lock/lock when chnage-workflow.sh completes 

## Observed Current Behavior

Describe what the system currently does.

## Desired Behavior

Describe what the system should do after the change.

## Reproduction

For a bug, provide exact steps to reproduce it.

For other change types, write "Not applicable."

## Constraints

List compatibility, security, performance, timing, or scope constraints.

## Known Relevant Files

List files or components if known.

## Out of Scope

List behavior or components that must not be changed.

## Success Criteria

Describe the observable evidence that proves the change works.
