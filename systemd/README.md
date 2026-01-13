# systemd Timers (User)

This directory contains user-level systemd units for the automation stack.

## What is scheduled

### Backups
- Every 6 hours
- PostgreSQL + n8n data
- Retention pruning included

### Podman prune
- Daily
- Safe cleanup of unused resources

## Why user timers

- No root required
- Integrates with podman
- Logs via `journalctl --user`
- Survives reboots

## Enable later (on Pi)

```bash
mkdir -p ~/.config/systemd/user
cp systemd/user/* ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now automation-backup.timer
systemctl --user enable --now automation-prune.timer
