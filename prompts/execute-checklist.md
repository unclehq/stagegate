You are the primary verification agent.

Read MANUAL_CHECKLIST.md and execute every feasible Critical and Important
check.

Run checks concurrently where they are independent. Serialize only checks that
share a port, a fixture, a build artifact, or ordered state. Record the results
as you go and write the report once at the end.

Create VERIFICATION_REPORT.md.

For every check record:

- Check ID
- Action actually performed
- Expected result
- Actual result
- Evidence
- Status: PASS, FAIL, BLOCKED, or NOT RUN
- Defect reference, when applicable

Never mark an unexecuted check as PASS.
Never infer browser behavior from a successful compilation.
Do not silently repair failures while testing.

Evidence means the specific output that establishes the result — the assertion
that fired, the status line, the log line with the error. Quote those, not
whole transcripts. The final audit reads this report and checks your evidence
against the claim, so it has to be the decisive part, not the surrounding
noise.

After verification, create DEFECTS.md for every failed check.
