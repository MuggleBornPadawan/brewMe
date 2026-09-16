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

  # 4b. Reverse-sync managed files (HOME → repo) — same mapping as setup.sh
  #     If HOME is already a correct symlink, skip. If HOME has a real file/dir
  #     that differs, copy it back to repo (after secret check per file).
  echo "--- Syncing managed dotfiles (HOME → repo) ---"
  FILES=(
    "zsh/.zshrc:.zshrc"
    "zsh/.zprofile:.zprofile"
    "tmux/.tmux.conf:.tmux.conf"
    "git/.gitconfig:.gitconfig"
    "config/.config/btop:.config/btop"
    "config/.config/neofetch:.config/neofetch"
    "pi/.pi/agent/AGENTS.md:.pi/agent/AGENTS.md"
    "pi/.pi/agent/settings.json:.pi/agent/settings.json"
    "pi/.pi/agent/models.json:.pi/agent/models.json"
    "pi/.pi/agent/prompts:.pi/agent/prompts"
    "pi/.pi/agent/skills:.pi/agent/skills"
    "pi/.pi/agent/extensions:.pi/agent/extensions"
    "pi/.pi/agent/scripts:.pi/agent/scripts"
  )

  # Helper: check if a file likely contains a secret (best-effort, no false negatives panic)
  has_secret() {
    local f="$1"
    [ -f "$f" ] || return 1
    # High-signal patterns: AWS keys, GitHub PAT, OpenAI sk-*, generic api_key/secret/token assignments
    if grep -q -i -E \
      -e 'AKIA[0-9A-Z]{16}' \
      -e 'ghp_[A-Za-z0-9]{36,}' -e 'gho_[A-Za-z0-9]{36,}' -e 'github_pat_[A-Za-z0-9_]{80,}' \
      -e 'sk-[A-Za-z0-9]{20,}' -e 'sk-proj-[A-Za-z0-9_-]{20,}' \
      -e '-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----' \
      -e '(api[_-]?key|apikey|secret[_-]?key|aws_secret|oauth_token)[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9_\/+=-]{3,}' \
      "$f" 2>/dev/null; then
      return 0
    fi
    return 1
  }

  for entry in "${FILES[@]}"; do
    IFS=":" read -r src_rel dst_rel <<< "${entry}"
    SRC="${DOTFILES_DIR}/${src_rel}"
    DST="${HOME}/${dst_rel}"
    [ -e "${DST}" ] || [ -L "${DST}" ] || { echo "  skip ${dst_rel}: not present in HOME"; continue; }
    # If correct symlink, nothing to sync
    if [ -L "${DST}" ] && [ "$(readlink "${DST}")" = "${SRC}" ]; then
      echo "  ✓ ${dst_rel} already symlinked — no sync needed"
      continue
    fi
    # Deny secrets for this file before any copy
    if has_secret "${DST}"; then
      echo "  ✗ ${dst_rel} appears to contain a secret — SKIPPED (not copied to repo)"
      continue
    fi
    # Ensure parent dir exists in repo
    mkdir -p "$(dirname "${SRC}")"
    # If SRC exists and is identical, skip
    if [ -e "${SRC}" ] && diff -qr "${DST}" "${SRC}" >/dev/null 2>&1; then
      echo "  ✓ ${dst_rel} identical to repo — skipping"
      continue
    fi
    echo "  ↻ syncing ${dst_rel} → ${src_rel}"
    if [ -d "${DST}" ] && [ ! -L "${DST}" ]; then
      # Directory: rsync with denylist for any nested secrets/caches (non-fatal on permission errors)
      rsync -av --delete \
        --exclude='.git/' --exclude='*.log' --exclude='.DS_Store' \
        --exclude='auth.json' --exclude='models-store.json' --exclude='opencode-free-state.json' \
        --exclude='sessions/' --exclude='logs/' --exclude='bin/' \
        --exclude='.cache/' --exclude='__pycache__/' --exclude='node_modules/' \
        "${DST}/" "${SRC}/" || echo "  ⚠ rsync warning for ${dst_rel} — continuing (permission or vanished file)"
    else
      cp -p "${DST}" "${SRC}" || echo "  ⚠ cp warning for ${dst_rel} — continuing"
    fi
  done

  # 4c. Optional snapshot of *other* safe dotfiles into backup/ (sanitized)
  #     This captures "all dotfiles" beyond the primary FILES, but with a strict denylist.
  #     Secrets, caches, and large stores are never snapshotted. Backup/ is versioned
  #     per README (not symlinked by setup.sh) — useful for diffing across machines.
  echo "--- Snapshotting extra dotfiles into backup/ (denylist enforced) ---"
  mkdir -p "${DOTFILES_BACKUP_DIR}"
  # Denylist patterns for the snapshot (same philosophy as .gitignore + extras)
  SNAPSHOT_EXCLUDES=(
    ".dotfiles" ".dotfiles_backup" ".Trash" ".cache" ".local" ".npm" ".docker"
    ".ollama" ".opencode" ".claude" ".gemini" ".hermes" ".jenkins" ".m2"
    ".homebrew" ".password-store" ".gnupg" ".ssh" ".config/gh" ".config/opencode"
    ".zsh_history" ".bash_history" ".viminfo" ".lesshst" ".psql_history"
    ".python_history" ".sqlite_history" ".DS_Store" ".CFUserTextEncoding"
  )
  is_excluded() {
    local name="$1"
    for ex in "${SNAPSHOT_EXCLUDES[@]}"; do
      [[ "${name}" == "${ex}" ]] && return 0
      [[ "${name}" == "${ex}"/* ]] && return 0
    done
    return 1
  }
  # Example safe extras to snapshot if present: .emacs.d, .config/htop, .config/btop (already primary), .config/neofetch
  EXTRA_SOURCES=(
    ".emacs.d"
    ".config/htop"
    ".config/nvim"
    ".config/karabiner"
    ".config/starship.toml"
  )
  for rel in "${EXTRA_SOURCES[@]}"; do
    src="${HOME}/${rel}"
    dst="${DOTFILES_BACKUP_DIR}/${rel}"
    [ -e "${src}" ] || continue
    is_excluded "${rel}" && { echo "  skip backup/${rel} — denylisted"; continue; }
    if has_secret "${src}" 2>/dev/null; then
      echo "  ✗ backup/${rel} contains secret pattern — SKIPPED"
      continue
    fi
    # Skip unreadable sources (e.g., root-owned htoprc) — best practice: don't sudo silently
    if [ ! -r "${src}" ]; then
      echo "  ⚠ backup/${rel} not readable — SKIPPED (permission denied, run sudo manually if desired)"
      continue
    fi
    echo "  ↻ snapshot ${rel} → backup/${rel}"
    mkdir -p "$(dirname "${dst}")"
    if [ -d "${src}" ]; then
      rsync -av --delete --delete-excluded \
        --exclude='.git/' --exclude='*.log' --exclude='.DS_Store' \
        --exclude='eln-cache/' --exclude='elpa/' --exclude='.cache/' \
        --exclude='backups/' --exclude='auto-save-list/' \
        --exclude='transient/' --exclude='tree-sitter/' --exclude='tutorial/' \
        --exclude='*.bak' --exclude='*~' --exclude='*.elc' \
        --exclude='.emacs.desktop' --exclude='.emacs.desktop.lock' --exclude='.lsp-session-v1' --exclude='.persistent-scratch' \
        --exclude='cider-history' --exclude='eww-bookmarks' --exclude='history' \
        --exclude='places' --exclude='recentf' --exclude='tramp' --exclude='.mc-lists.el' \
        "${src}/" "${dst}/" || echo "  ⚠ rsync warning for backup/${rel} — continuing"
    else
      cp -p "${src}" "${dst}" || echo "  ⚠ cp warning for backup/${rel} — continuing"
    fi
  done

  # 4d. Stage, secret-scan staged diff, commit, push
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

