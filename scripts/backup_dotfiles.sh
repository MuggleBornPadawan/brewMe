#!/usr/bin/env bash

# Dotfiles Backup Script
# This script backs up specified configuration files and directories from your home folder (~)
# to a local backup directory within this repository.

set -euo pipefail

# Ensure standard system and package manager paths are available (especially for cron)
PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
export PATH

# Determine the workspace root directory (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${REPO_ROOT}/backup"

# Default files to back up (relative to home directory)
# You can customize this list to include other files or folders.
DEFAULT_DOTFILES=(
    ".tmux.conf"
    ".tmux"
    ".zshrc"
    ".gitconfig"
    ".emacs.d/init.el"
    ".config/btop"
    ".config/htop"
    ".config/neofetch"
)

# Parse arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -n, --dry-run  Show what would be copied without actually copying anything"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo "=== DRY RUN: No files will be modified ==="
fi

echo "Backup directory: ${BACKUP_DIR}"
if [ "$DRY_RUN" = false ]; then
    mkdir -p "${BACKUP_DIR}"
fi

# Change to home directory to keep path operations clean and relative
cd "${HOME}"

success_count=0
failure_count=0
skipped_count=0

for item in "${DEFAULT_DOTFILES[@]}"; do
    if [ -e "${item}" ]; then
        # Calculate destination directory inside the backup folder
        rel_parent_dir="$(dirname "${item}")"
        dest_parent_dir="${BACKUP_DIR}/${rel_parent_dir}"

        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would back up: ~/${item} -> ${BACKUP_DIR}/${item}"
            success_count=$((success_count + 1))
        else
            echo "Backing up: ~/${item} -> ${BACKUP_DIR}/${item}"
            
            copy_failed=false
            if [ -d "${item}" ]; then
                mkdir -p "${BACKUP_DIR}/${item}"
                # For directories, use rsync to sync and clean up deleted files
                if command -v rsync >/dev/null 2>&1; then
                    rsync -a --delete "${item}/" "${BACKUP_DIR}/${item}/" || copy_failed=true
                else
                    # Fallback to cp if rsync is not available
                    cp -RPp "${item}/." "${BACKUP_DIR}/${item}/" || copy_failed=true
                fi
            else
                mkdir -p "${dest_parent_dir}"
                # For single files
                if command -v rsync >/dev/null 2>&1; then
                    rsync -a "${item}" "${dest_parent_dir}/" || copy_failed=true
                else
                    cp -Pp "${item}" "${dest_parent_dir}/" || copy_failed=true
                fi
            fi

            if [ "$copy_failed" = true ]; then
                echo "Warning: Failed to back up ~/${item}. (Check permissions or owner)"
                failure_count=$((failure_count + 1))
            else
                success_count=$((success_count + 1))
            fi
        fi
    else
        echo "Skipping: ~/${item} (not found)"
        skipped_count=$((skipped_count + 1))
    fi
done

echo ""
echo "=== Backup Summary ==="
if [ "$DRY_RUN" = true ]; then
    echo "Would successfully back up: ${success_count} item(s)"
else
    echo "Successfully backed up: ${success_count} item(s)"
    if [ "${failure_count}" -gt 0 ]; then
        echo "Failed to back up: ${failure_count} item(s)"
    fi
fi
echo "Skipped (not found): ${skipped_count} item(s)"
echo "Backup location: ${BACKUP_DIR}"
