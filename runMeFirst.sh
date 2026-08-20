#!/usr/bin/env bash

set -euo pipefail

# Determine script's own directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

# Run backups and push before updates

echo "=== Running Backups ==="

# Run backup scripts using the resolved repository root
if [ -f "${REPO_ROOT}/scripts/backup_skills.sh" ]; then
    "${REPO_ROOT}/scripts/backup_skills.sh"
fi

echo "=== Pushing Dotfiles ==="
cd ~/.dotfiles
git add .
if ! git diff-index --quiet HEAD --; then
    git commit -m "update configs"
    git push
else
    echo "No config changes to push."
fi

echo "=== Pushing brewMe Repo ==="
cd "$REPO_ROOT"
git add .
if ! git diff-index --quiet HEAD --; then
    git commit -m "update brewMe scripts"
    git push
else
    echo "No script changes to push."
fi

# Now perform system package updates

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
        echo "$outdated_pip" | xargs pip install -U
    else
        echo "All pip packages are up to date."
    fi
else
    echo "pip not found, skipping."
fi

echo "=== Done ==="
