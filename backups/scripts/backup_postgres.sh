#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/backups/postgres"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUT_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

mkdir -p "${OUT_DIR}"

podman exec n8n-postgres \
  pg_dump -U n8n n8n \
  | gzip > "${OUT_DIR}/n8n.sql.gz"

echo "[OK] Postgres backup created at ${OUT_DIR}"
