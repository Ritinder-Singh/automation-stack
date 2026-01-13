#!/usr/bin/env bash
set -euo pipefail

echo "[START] Backup run $(date)"

./backup_postgres.sh
./backup_n8n_data.sh
./prune_backups.sh

echo "[DONE] Backup completed $(date)"
