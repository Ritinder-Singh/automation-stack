#!/usr/bin/env bash
set -euo pipefail

BACKUP_BASE="/backups"
DAYS_TO_KEEP=7

find "${BACKUP_BASE}" \
  -type d \
  -mindepth 2 \
  -mtime +${DAYS_TO_KEEP} \
  -exec rm -rf {} \;

echo "[OK] Old backups pruned"
