#!/usr/bin/env bash
set -euo pipefail

echo "[START] Podman prune $(date)"

# Remove stopped containers
podman container prune -f

# Remove dangling images
podman image prune -f

# Remove unused networks
podman network prune -f

# Remove unused volumes (VERY conservative)
# Only removes anonymous volumes not used by any container
podman volume prune -f

echo "[DONE] Podman prune $(date)"
