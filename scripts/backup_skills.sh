#!/usr/bin/env bash

# Agent Skills Backup Script
# This script backs up Gemini/Agy and OpenCode agent skills
# to a local backup directory within this repository.

set -euo pipefail

# Ensure standard system paths are available
PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
export PATH

# Determine the workspace root directory (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles/backup"

# Define skills directories to back up (source path and destination subfolder)
KEYS=("gemini_skills" "opencode_skills")
SRCS=("${HOME}/.gemini/config/skills" "${HOME}/.config/opencode/skills")

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

success_count=0
failure_count=0
skipped_count=0

for i in "${!KEYS[@]}"; do
    key="${KEYS[$i]}"
    src_dir="${SRCS[$i]}"
    dest_dir="${BACKUP_DIR}/${key}"

    if [ -d "${src_dir}" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would back up: ${src_dir} -> ${dest_dir}"
            success_count=$((success_count + 1))
        else
            echo "Backing up: ${src_dir} -> ${dest_dir}"
            mkdir -p "${dest_dir}"
            
            copy_failed=false
            if command -v rsync >/dev/null 2>&1; then
                rsync -a --delete "${src_dir}/" "${dest_dir}/" || copy_failed=true
            else
                # Fallback to cp if rsync is not available
                cp -RPp "${src_dir}/." "${dest_dir}/" || copy_failed=true
            fi

            if [ "$copy_failed" = true ]; then
                echo "Warning: Failed to back up ${src_dir}."
                failure_count=$((failure_count + 1))
            else
                success_count=$((success_count + 1))
            fi
        fi
    else
        echo "Skipping: ${src_dir} (not found)"
        skipped_count=$((skipped_count + 1))
    fi
done

echo ""
echo "=== Backup Summary ==="
if [ "$DRY_RUN" = true ]; then
    echo "Would successfully back up: ${success_count} directory/directories"
else
    echo "Successfully backed up: ${success_count} directory/directories"
    if [ "${failure_count}" -gt 0 ]; then
        echo "Failed to back up: ${failure_count} directory/directories"
    fi
fi
echo "Skipped (not found): ${skipped_count} directory/directories"
echo "Backup location: ${BACKUP_DIR}"
