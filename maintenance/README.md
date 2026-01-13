# Maintenance

This directory contains housekeeping scripts for the automation stack.

## Podman prune

`prune_podman.sh` safely removes:
- stopped containers
- dangling images
- unused networks
- unused anonymous volumes

It does NOT affect:
- running containers
- named volumes in use
- active images

## Recommended cadence

- Every 24 hours
- Or every 12 hours on heavy experimentation systems
