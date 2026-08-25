---
description: Generate a commit message from staged changes and commit
argument-hint: "[extra context]"
---
Generate a commit message for the staged changes (`git diff --cached`) and commit them.

If nothing is staged, tell me and stop — do not stage files yourself unless I explicitly asked in the extra context.

Message format (Conventional Commits):
- **Subject line**: `type(scope): imperative summary` — max 72 chars, no trailing period
  - Types: feat, fix, refactor, test, docs, chore, perf, ci
  - The subject must complete the sentence "If applied, this commit will..."
- **Body** (only if the why isn't obvious from the diff): wrap at 72 chars, explain *why* the change was made, not a line-by-line listing of *what* changed

Rules:
- Look at the actual diff, not just file names; check recent `git log --oneline -10` to match the repo's existing style if it differs from Conventional Commits
- Never claim work that isn't in the diff; never mention Claude, AI, or this session in the message
- If the staged changes mix unrelated concerns, suggest splitting them into separate commits before proceeding

${1:+Additional context from me: $1}

Commit using a heredoc so the message formatting is preserved exactly.
