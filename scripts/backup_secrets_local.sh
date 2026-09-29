#!/usr/bin/env bash
# Dedicated local encrypted backup script for sensitive credentials (.ssh, .gnupg, .password-store)
# These files MUST NOT be committed to git repositories.
set -euo pipefail

BACKUP_DIR="${HOME}/.backups/credentials"
mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
ARCHIVE_NAME="secrets_backup_${TIMESTAMP}.tar.gz"
ENCRYPTED_ARCHIVE="${BACKUP_DIR}/${ARCHIVE_NAME}.gpg"

echo "=== Local Encrypted Secrets Backup ==="
echo "Target backup location: ${BACKUP_DIR}"

# Check for presence of secret directories / files
TARGETS=()
for item in ".ssh" ".gnupg" ".password-store" ".git-credentials"; do
  if [ -e "${HOME}/${item}" ]; then
    TARGETS+=("${item}")
  fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "No sensitive credential directories found to back up."
  exit 0
fi

echo "Items to include in encrypted archive: ${TARGETS[*]}"
TMP_TAR=$(mktemp "${TMPDIR:-/tmp}/secrets_backup.XXXXXX.tar.gz")
chmod 600 "${TMP_TAR}"

cleanup() {
  rm -f "${TMP_TAR}"
}
trap cleanup EXIT

# Create tarball relative to HOME
tar -czf "${TMP_TAR}" -C "${HOME}" "${TARGETS[@]}"

echo "Encrypting archive with GPG (AES256 symmetric cipher)..."
if command -v gpg >/dev/null 2>&1; then
  gpg --symmetric --cipher-algo AES256 --output "${ENCRYPTED_ARCHIVE}" "${TMP_TAR}"
  chmod 600 "${ENCRYPTED_ARCHIVE}"
  echo "✓ Successfully created encrypted archive: ${ENCRYPTED_ARCHIVE}"
  echo ""
  echo "To restore on this or a new machine:"
  echo "  gpg -d \"${ENCRYPTED_ARCHIVE}\" | tar -xzv -C \"\${HOME}\""
else
  echo "✗ Error: gpg not found in PATH. Please install gnupg (brew install gnupg)."
  exit 1
fi

# Prune old backups keeping the 5 most recent
echo "Pruning older backups (keeping last 5)..."
ls -1t "${BACKUP_DIR}"/secrets_backup_*.tar.gz.gpg 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true

echo "=== Done ==="
