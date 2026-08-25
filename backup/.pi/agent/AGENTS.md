# Global Agent Context

## Hardware Spec
- **Chip:** Apple M1 Max - 10 cores (ARM64)
- **Memory:** 32 GB Unified Memory

## Technology Stack
- **Primary Language:** Clojure (Clojure / ClojureScript) - JVM
- **Build Tools:** Clojure CLI (deps.edn), Leiningen, shadow-cljs (for CLJS)
- **Database:** PostgreSQL (primary), SQLite (local/embedded)
- **Editor:** Emacs (with CIDER / clojure-mode)
- **AI / Runtime:** Ollama (local LLMs), Pi Coding Agent (opencode/x-preview-f-free)
- **Testing:** clojure.test, Kaocha / Cognitect test-runner
- **Infra:** Docker, JVM 21+

## Preferences
- Keep changes surgical and minimal
- Verify with `bash` before claiming done
- No auto-push to main
- REPL-driven workflow: prefer nREPL/CIDER, evaluate at REPL before writing files
- Data-oriented & immutable: prefer pure functions, `clojure.spec` / Malli for validation
- Style: follow `cljfmt` / `clj-kondo` linting, use `deps.edn` over Leiningen for new projects
- DB: PostgreSQL for prod, SQLite for local/dev and tests - use `next.jdbc` + HoneySQL
- Emacs: respect CIDER jack-in, `cider-nrepl`, no VS Code assumptions
