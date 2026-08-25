---
description: Hunt for bugs, edge cases, and leaks in code
argument-hint: "[file]"
---
Proactively hunt for bugs in ${1:-the specified module}.

Focus on:
1. **Edge cases** — empty inputs, null/undefined, zero, negative numbers, huge values, unicode
2. **Error handling** — swallowed exceptions, missing failure paths, unchecked results
3. **Concurrency/state** — race conditions, shared mutable state, ordering assumptions
4. **Resource leaks** — unclosed files/connections, missing cleanup on error paths
5. **Boundary assumptions** — off-by-one errors, timezone/locale issues, integer overflow

For each suspected bug: explain the exact scenario that triggers it, rate likelihood × impact, and propose a fix.
Verify claims against the actual code — no speculation without reading the relevant paths.
Write failing test cases for confirmed bugs.
