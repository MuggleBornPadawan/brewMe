---
description: Review code changes for bugs, security, and quality
argument-hint: "[staged|branch|<file>] (default: staged)"
---
Review the following changes: ${1:-the staged changes (`git diff --cached`)}

Focus on, in priority order:
1. **Bugs and logic errors** — incorrect conditions, off-by-one errors, unhandled edge cases
2. **Security issues** — injection, unsafe deserialization, secrets in code, missing auth checks
3. **Error handling gaps** — swallowed exceptions, missing failure paths, unchecked promises
4. **Clarity** — misleading names, dead code, duplicated logic

Rules:
- Read the surrounding context of each change before commenting — don't review diffs in isolation
- Only report real issues; do not pad the review with style nitpicks
- For each finding: cite the file and line, explain the problem, suggest a concrete fix
- If there are no significant issues, say so plainly instead of inventing feedback

End with a one-line verdict: APPROVE, APPROVE WITH NITS, or CHANGES NEEDED.
