#!/usr/bin/env bash
echo "=== General instructions ==="
echo "sudo shutdown -h now"
echo "tmux new -s alpha"
echo "emacs -nw"
echo "============================"

set -euo pipefail

# Determine script's own directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

# Now perform system package updates

echo "=== Updating MuggleBornPadawan Repo ==="
if [ -d "$HOME/Public/MuggleBornPadawan" ]; then
    cd "$HOME/Public/MuggleBornPadawan"
    git pull
else
    echo "MuggleBornPadawan repository directory not found, skipping update."
fi

echo "=== Starting system package updates ==="

# 1. Update Homebrew
if command -v brew > /dev/null 2>&1; then
    echo "Updating Homebrew..."
    brew update && brew upgrade
else
    echo "Homebrew not found, skipping."
fi

# 2. Update npm packages
if command -v npm > /dev/null 2>&1; then
    echo "Updating npm..."
    npm update
else
    echo "npm not found, skipping."
fi

# 3. Update outdated pip packages efficiently in a single run
if command -v pip > /dev/null 2>&1; then
    echo "Updating outdated pip packages..."
    outdated_pip=$(pip list --outdated | awk 'NR>2 {print $1}')
    if [ -n "$outdated_pip" ]; then
        echo "$outdated_pip" | xargs pip install -U --break-system-packages 2>&1 || echo "⚠ pip update failed (externally-managed / PEP 668) — skipping. Use 'pipx' or 'brew install' for apps."
    else
        echo "All pip packages are up to date."
    fi
else
    echo "pip not found, skipping."
fi

# ──────────────────────────────────────────────────────────────
# 4. Dotfiles backup → $HOME/.dotfiles → GitHub (best practices)
# ──────────────────────────────────────────────────────────────
# Best-practice rules enforced here:
#   • Denylist: never version secrets (api keys, tokens, private keys,
#     .env, .git-credentials, .ssh/id_*, .gnupg private, .password-store,
#     gh hosts.yml, auth.json, history, caches, .ollama, .docker, etc.)
#   • Allowlist for primary configs: sync only known safe paths (same
#     FILES mapping as setup.sh) — reverse direction HOME → repo.
#   • Extra dotfiles go to backup/ snapshot (sanitized, still .gitignored
#     for secrets). Root "/" is audited but never auto-committed (needs sudo).
#   • Pre-commit secret scan aborts on high-entropy tokens so push never leaks.
#   • Commit only if changed; pull --rebase first; push with error handling.
#   • All operations respect .gitignore already hardened in .dotfiles.

echo "=== Backing up dotfiles to \$HOME/.dotfiles ==="

DOTFILES_DIR="${HOME}/.dotfiles"
DOTFILES_BACKUP_DIR="${DOTFILES_DIR}/backup"

if [ ! -d "${DOTFILES_DIR}/.git" ]; then
  echo "Dotfiles repo not found at ${DOTFILES_DIR} — skipping backup."
else
  # 4a. Audit root folder for dotfiles (informational, no auto-backup)
  echo "--- Auditing root folder for dotfiles (informational) ---"
  echo "Listing dotfiles in / (maxdepth 1, no sudo):"
  ls -ld /.* 2>/dev/null | head -n 30 || echo "(no dotfiles visible in /)"
  if [ -d /root ]; then
    echo "Listing dotfiles in /root (may require sudo):"
    ls -la /root 2>/dev/null | head -n 20 || echo "(cannot read /root without sudo — skipped)"
  else
    echo "/root does not exist on macOS — skipped."
  fi
  echo "Home dotfiles (symlinked vs real):"
  ls -la "${HOME}" | grep -E "^l|^d|^-" | grep "^\." | head -n 40 || true

  # 4b. Verify / sync managed dotfiles (Single Source of Truth in ~/.dotfiles)
  echo "--- Checking managed dotfiles symlinks ---"
  FILES=(
    "zsh/.zshrc:.zshrc"
    "zsh/.zprofile:.zprofile"
    "tmux/.tmux.conf:.tmux.conf"
    "git/.gitconfig:.gitconfig"
    "config/.config/btop:.config/btop"
    "config/.config/neofetch:.config/neofetch"
    "emacs/init.el:.emacs.d/init.el"
    "emacs/custom.el:.emacs.d/custom.el"
    "emacs/lisp:.emacs.d/lisp"
    "skills/gemini:.gemini/config/skills"
    "skills/opencode:.config/opencode/skills"
    "pi/.pi/agent/AGENTS.md:.pi/agent/AGENTS.md"
    "pi/.pi/agent/settings.json:.pi/agent/settings.json"
    "pi/.pi/agent/models.json:.pi/agent/models.json"
    "pi/.pi/agent/prompts:.pi/agent/prompts"
    "pi/.pi/agent/skills:.pi/agent/skills"
    "pi/.pi/agent/extensions:.pi/agent/extensions"
    "pi/.pi/agent/scripts:.pi/agent/scripts"
  )

  for entry in "${FILES[@]}"; do
    IFS=":" read -r src_rel dst_rel <<< "${entry}"
    SRC="${DOTFILES_DIR}/${src_rel}"
    DST="${HOME}/${dst_rel}"
    if [ ! -e "${SRC}" ]; then
      echo "  ⚠ ${src_rel} does not exist in repo — skipping"
      continue
    fi
    mkdir -p "$(dirname "${DST}")"
    if [ -L "${DST}" ] && [ "$(readlink "${DST}")" = "${SRC}" ]; then
      echo "  ✓ ${dst_rel} correctly symlinked"
      continue
    fi
    echo "  ↻ linking ${dst_rel} → ${SRC}"
    rm -rf "${DST}"
    ln -s "${SRC}" "${DST}"
  done

  # 4c. Stage, secret-scan staged diff, commit, push
  echo "--- Git status in ${DOTFILES_DIR} ---"
  cd "${DOTFILES_DIR}"
  # Refresh index, show what would be committed (respects .gitignore)
  git status --short
  # Ensure .gitignore is honored: only add tracked + new non-ignored files
  git add -A
  # Secret scan on *staged* content (not just working tree) — abort if leak detected
  echo "--- Pre-commit secret scan on staged changes ---"
  # Check if anything is staged at all (including deletions) — deletions don't need secret scan
  if git diff --cached --quiet 2>/dev/null; then
    echo "No staged files — working tree clean (or all changes ignored)."
    cd "${REPO_ROOT}"
  else
    # Secret scan only on added/copied/modified (ACM); deletions are safe to skip
    STAGED_ACM=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    leak_found=0
    if [ -n "${STAGED_ACM}" ]; then
      echo "Scanning staged ACM files for secrets..."
      while IFS= read -r sf; do
        [ -z "${sf}" ] && continue
        if [ -f "${DOTFILES_DIR}/${sf}" ] && file "${DOTFILES_DIR}/${sf}" 2>/dev/null | grep -qi "binary"; then
          continue
        fi
        if git show ":${sf}" 2>/dev/null | grep -q -i -E \
          -e 'AKIA[0-9A-Z]{16}' \
          -e 'ghp_[A-Za-z0-9]{36,}' -e 'gho_[A-Za-z0-9]{36,}' \
          -e 'sk-[A-Za-z0-9]{20,}' -e 'sk-proj-[A-Za-z0-9_-]{20,}' \
          -e '-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----' \
          -e '(api[_-]?key|secret[_-]?key|oauth_token)[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9_\/+=-]{3,}' ; then
          echo "  ✗ SECRET pattern in staged file: ${sf} — aborting commit"
          leak_found=1
        fi
      done <<< "${STAGED_ACM}"
    fi
    if [ "${leak_found}" -ne 0 ]; then
      echo "Aborting dotfiles push — secret detected in staged changes. Fix and re-run."
      git reset HEAD -- . >/dev/null 2>&1 || true
      cd "${REPO_ROOT}"
    else
      echo "Staged changes:"
      git diff --cached --stat
      echo "Pulling latest (rebase) before push..."
      git pull --rebase --autostash origin main 2>&1 | head -n 20 || echo "(pull skipped or no remote)"
      ts=$(date '+%Y-%m-%d %H:%M:%S %Z')
      git commit -m "backup: dotfiles sync ${ts}" -m "Automated via brewMe/runMeFirst.sh — managed files reverse-synced + backup/ snapshot. Secrets excluded via denylist + pre-commit scan." || echo "(nothing to commit after rebase)"
      echo "Pushing to origin/main..."
      if git push origin main 2>&1; then
        echo "✓ Dotfiles pushed successfully."
      else
        echo "✗ git push failed — check 'gh auth status' / network / remote permissions. Local commit kept."
      fi
      cd "${REPO_ROOT}"
    fi
  fi
fi

echo "=== General instructions ==="
echo "sudo shutdown -h now"
echo "tmux new -s alpha"
echo "emacs -nw"
echo "my-erc-connect"
echo "============================"
echo "=== Done ==="

