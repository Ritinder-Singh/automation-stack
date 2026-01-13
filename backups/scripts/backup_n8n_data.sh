#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/backups/n8n"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUT_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

mkdir -p "${OUT_DIR}"

tar -czf "${OUT_DIR}/n8n_data.tar.gz" \
  -C /var/lib/containers/storage/volumes \
  n8n_data/_data

echo "[OK] n8n data backup created at ${OUT_DIR}"
