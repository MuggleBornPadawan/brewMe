---
description: Analyze a bug report or issue and implement a fix
argument-hint: "<issue URL, issue number, or bug description>"
---
Fix this issue: $ARGUMENTS

Work through it systematically:

1. **Understand the bug**
   - If given a GitHub issue URL or number, fetch it with `gh issue view` (fall back to the API via curl if `gh` is unavailable)
   - Reproduce or trace the failure path before changing anything
   - Identify the root cause, not just the symptom

2. **Locate the code**
   - Find all files involved in the failure path
   - Check whether similar bugs exist elsewhere in the codebase

3. **Implement the fix**
   - Make the minimal change that fixes the root cause
   - Do not refactor unrelated code while you're in there
   - Add or update a test that fails before the fix and passes after

4. **Verify**
   - Run the relevant tests (and the broader suite if it's fast)
   - Summarize: root cause → fix → test evidence

If the issue is ambiguous, state your interpretation of the bug before fixing, and flag any assumptions you made.
