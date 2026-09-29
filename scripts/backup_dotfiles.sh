#!/usr/bin/env bash
set -euo pipefail

# Ensure standard system and package manager paths are available (especially for launchd/cron)
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export PATH

DOTFILES_DIR="${HOME}/.dotfiles"

echo "=== [$(date '+%Y-%m-%d %H:%M:%S %Z')] Starting Dotfiles Sync ==="

if [ ! -d "${DOTFILES_DIR}/.git" ]; then
  echo "Dotfiles repo not found at ${DOTFILES_DIR} — skipping backup."
  exit 1
fi

# 1. Run setup.sh to adopt any new/updated configurations and ensure symlinks
if [ -f "${DOTFILES_DIR}/setup.sh" ]; then
  echo "--- Running dotfiles setup.sh to verify & adopt links ---"
  bash "${DOTFILES_DIR}/setup.sh"
fi

cd "${DOTFILES_DIR}"

# 2. Stage tracked + non-ignored files
echo "--- Git status in ${DOTFILES_DIR} ---"
git add -A

if git diff --cached --quiet 2>/dev/null; then
  echo "✓ Working tree clean — no changes to commit."
  exit 0
fi

# 3. Pre-commit secret scan on staged content
echo "--- Pre-commit secret scan on staged changes ---"
STAGED_ACM=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
leak_found=0

if [ -n "${STAGED_ACM}" ]; then
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
  exit 1
fi

echo "Staged changes:"
git diff --cached --stat

echo "Pulling latest before commit..."
git pull --rebase --autostash origin main 2>&1 || echo "(rebase skipped or no upstream changes)"

ts=$(date '+%Y-%m-%d %H:%M:%S %Z')
git commit -m "backup: dotfiles sync ${ts}" -m "Automated via brewMe/scripts/backup_dotfiles.sh. Secrets excluded via denylist + pre-commit scan." || echo "(nothing to commit after rebase)"

echo "Pushing to origin/main..."
if git push origin main 2>&1; then
  echo "✓ Dotfiles pushed successfully."
else
  echo "✗ git push failed — local commit kept."
  exit 1
fi

echo "=== Dotfiles sync completed successfully ==="
