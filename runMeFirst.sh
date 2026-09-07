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
        echo "$outdated_pip" | xargs pip install -U
    else
        echo "All pip packages are up to date."
    fi
else
    echo "pip not found, skipping."
fi

echo "=== General instructions ==="
echo "sudo shutdown -h now"
echo "tmux new -s alpha"
echo "emacs -nw"
echo "my-erc-connect"
echo "============================"
echo "=== Done ==="

