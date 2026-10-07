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

# 2. Dotfiles backup via Babashka
echo "=== Backing up dotfiles via Babashka ==="
if command -v bb > /dev/null 2>&1 && [ -f "$HOME/.dotfiles/coding-harness/skills/dotfiles-sync/scripts/backup_push.clj" ]; then
    bb "$HOME/.dotfiles/coding-harness/skills/dotfiles-sync/scripts/backup_push.clj"
else
    echo "⚠ Babashka or backup_push.clj not found, skipping dotfiles sync."
fi

echo "=== General instructions ==="
echo "sudo shutdown -h now"
echo "tmux new -s alpha"
echo "emacs -nw"
echo "my-erc-connect"
echo "============================"
echo "=== Done ==="

