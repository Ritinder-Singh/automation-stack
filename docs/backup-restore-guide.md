# Backup and Restore Guide

Complete guide for backing up and restoring your automation stack.

---

## Overview

Your automation stack includes automated backups for:
- **PostgreSQL database** - Workflow data, credentials, execution history
- **n8n data volume** - Workflow files, settings, local data
- **Python data volume** - Any persistent data from Python runtime

**Backup Schedule:** Every 6 hours (via systemd timer)
**Retention:** 7 days (automatically pruned)
**Location:** `/home/ritinder/backups/`

---

## Backup Strategy

### What Gets Backed Up

1. **PostgreSQL Database** (`n8n` database)
   - All workflows and workflow versions
   - Credentials (encrypted)
   - Execution history
   - User settings
   - Backed up as: `postgres/<timestamp>/n8n.sql.gz`

2. **n8n Data Volume** (`n8n_data`)
   - Workflow files
   - Custom nodes (if any)
   - Local file storage
   - Backed up as: `n8n/<timestamp>/n8n_data.tar.gz`

3. **Python Data Volume** (`python_data`)
   - Included in n8n data backup
   - Any files stored in `/app/data` within Python container

### What Doesn't Get Backed Up

- Container images (can be rebuilt)
- Temporary logs (not needed)
- `.env` file (store separately, securely)

---

## Manual Backup

### Backup Everything (Recommended)

```bash
/home/ritinder/developer/automation-stack/backups/scripts/backup_all.sh
```

This runs all backup scripts in sequence:
1. PostgreSQL database dump
2. n8n data volume archive
3. Cleanup old backups (> 7 days)

### Backup PostgreSQL Only

```bash
/home/ritinder/developer/automation-stack/backups/scripts/backup_postgres.sh
```

Creates: `/home/ritinder/backups/postgres/<timestamp>/n8n.sql.gz`

### Backup n8n Data Only

```bash
/home/ritinder/developer/automation-stack/backups/scripts/backup_n8n_data.sh
```

Creates: `/home/ritinder/backups/n8n/<timestamp>/n8n_data.tar.gz`

### Backup .env File (Manual)

**Important:** Your `.env` file contains secrets and is NOT backed up automatically.

```bash
# Copy to secure location
cp /home/ritinder/developer/automation-stack/compose/.env ~/secure-backups/.env.backup

# Or encrypt before backup
gpg -c /home/ritinder/developer/automation-stack/compose/.env
# Move the .env.gpg file to secure location
```

---

## Automated Backups

### Installing Systemd Timers

```bash
# Copy timer files
mkdir -p ~/.config/systemd/user
cp /home/ritinder/developer/automation-stack/systemd/user/* ~/.config/systemd/user/

# Reload systemd
systemctl --user daemon-reload

# Enable and start backup timer
systemctl --user enable --now automation-backup.timer

# Enable and start prune timer
systemctl --user enable --now automation-prune.timer

# Verify timers are active
systemctl --user list-timers
```

### Checking Backup Status

```bash
# List recent backups
ls -lh /home/ritinder/backups/postgres/
ls -lh /home/ritinder/backups/n8n/

# Check timer status
systemctl --user status automation-backup.timer

# View backup logs
journalctl --user -u automation-backup.service -n 50
```

### Modifying Backup Schedule

Edit: `~/.config/systemd/user/automation-backup.timer`

```ini
# Current: Every 6 hours
OnCalendar=*-*-* 00/6:00:00

# Examples:
# Every 12 hours: OnCalendar=*-*-* 00/12:00:00
# Daily at 2 AM: OnCalendar=*-*-* 02:00:00
# Every 4 hours: OnCalendar=*-*-* 00/4:00:00
```

After editing:
```bash
systemctl --user daemon-reload
systemctl --user restart automation-backup.timer
```

### Modifying Retention Period

Edit: `/home/ritinder/developer/automation-stack/backups/scripts/prune_backups.sh`

```bash
# Current: 7 days
find /home/ritinder/backups -type d -mtime +7 -exec rm -rf {} +

# Examples:
# 14 days: -mtime +14
# 30 days: -mtime +30
# 3 days: -mtime +3
```

---

## Restore Procedures

### Prerequisites

Before restoring:
1. Stop all services: `cd compose && podman-compose down`
2. Verify backup files exist and are not corrupted
3. Have .env file ready (if restoring to new system)

---

### Scenario 1: Restore PostgreSQL Database

**When to use:** Database corruption, lost workflows, need to rollback to previous state

```bash
# 1. Stop services
cd /home/ritinder/developer/automation-stack/compose
podman-compose down

# 2. Find the backup you want to restore
ls -lh /home/ritinder/backups/postgres/

# 3. Choose a backup timestamp (example: 2026-01-14_120000)
BACKUP_DATE="2026-01-14_120000"

# 4. Restore database
gunzip -c /home/ritinder/backups/postgres/${BACKUP_DATE}/n8n.sql.gz | \
  podman exec -i n8n-postgres psql -U n8n -d n8n

# 5. Restart services
podman-compose up -d

# 6. Verify
podman logs n8n
```

**Alternative method (if containers are running):**

```bash
# Restore without stopping services
BACKUP_DATE="2026-01-14_120000"

# Drop existing database (WARNING: This deletes current data!)
podman exec n8n-postgres psql -U n8n -d postgres -c "DROP DATABASE IF EXISTS n8n;"
podman exec n8n-postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n OWNER n8n;"

# Restore from backup
gunzip -c /home/ritinder/backups/postgres/${BACKUP_DATE}/n8n.sql.gz | \
  podman exec -i n8n-postgres psql -U n8n -d n8n

# Restart n8n to reload data
podman restart n8n
```

---

### Scenario 2: Restore n8n Data Volume

**When to use:** Lost workflow files, corrupted local storage, need complete reset

```bash
# 1. Stop services
cd /home/ritinder/developer/automation-stack/compose
podman-compose down

# 2. Remove existing volume (WARNING: This deletes current data!)
podman volume rm n8n_data

# 3. Recreate volume
podman volume create n8n_data

# 4. Find backup to restore
ls -lh /home/ritinder/backups/n8n/

# 5. Choose backup timestamp
BACKUP_DATE="2026-01-14_120000"

# 6. Extract backup to volume
# First, create a temporary container with the volume mounted
podman run --rm -v n8n_data:/restore -v /home/ritinder/backups:/backups:ro \
  alpine tar -xzf /backups/n8n/${BACKUP_DATE}/n8n_data.tar.gz -C /restore --strip-components=1

# 7. Restart services
podman-compose up -d

# 8. Verify
podman logs n8n
```

---

### Scenario 3: Complete System Restore

**When to use:** New server, complete failure, migration to new hardware

#### Preparation on Old System (if accessible)

```bash
# 1. Run final backup
/home/ritinder/developer/automation-stack/backups/scripts/backup_all.sh

# 2. Copy backups to external storage
rsync -av /home/ritinder/backups/ /mnt/external/backups/

# 3. Save .env file (encrypted)
gpg -c /home/ritinder/developer/automation-stack/compose/.env
# Save .env.gpg to external storage

# 4. Optional: Export podman volumes as archives
podman volume export n8n_data > n8n_data.tar
podman volume export n8n_postgres_data > n8n_postgres_data.tar
```

#### Restore on New System

```bash
# 1. Clone repository or copy automation-stack directory
git clone <your-repo-url> automation-stack
# OR: rsync -av old-rpi:~/automation-stack/ ~/automation-stack/

# 2. Copy backups
rsync -av /mnt/external/backups/ /home/ritinder/backups/

# 3. Restore .env file
gpg -d .env.gpg > compose/.env
# Or manually recreate .env from .env.example

# 4. Update .env with new IP address (if different)
nano compose/.env
# Change N8N_HOST to new IP

# 5. Build and start services (creates fresh volumes)
cd compose
podman-compose up -d --build

# 6. Wait for services to initialize (10-15 seconds)
sleep 15

# 7. Stop services to restore data
podman-compose down

# 8. Restore PostgreSQL (choose your backup date)
BACKUP_DATE="2026-01-14_120000"
cd /home/ritinder/developer/automation-stack/compose
podman-compose up -d postgres
sleep 5

gunzip -c /home/ritinder/backups/postgres/${BACKUP_DATE}/n8n.sql.gz | \
  podman exec -i n8n-postgres psql -U n8n -d n8n

podman-compose down

# 9. Restore n8n data volume
podman volume rm n8n_data
podman volume create n8n_data

podman run --rm -v n8n_data:/restore -v /home/ritinder/backups:/backups:ro \
  alpine tar -xzf /backups/n8n/${BACKUP_DATE}/n8n_data.tar.gz -C /restore --strip-components=1

# 10. Start all services
podman-compose up -d

# 11. Verify everything works
../scripts/health-check.sh
```

---

### Scenario 4: Point-in-Time Recovery

**When to use:** Need to restore to specific point in time, investigate historical data

```bash
# 1. List all available backups
ls -lt /home/ritinder/backups/postgres/

# 2. Choose the backup closest to desired time
BACKUP_DATE="2026-01-14_080000"  # Example: 8 AM on Jan 14

# 3. Create a test database (to inspect without affecting production)
podman exec n8n-postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n_restore;"

# 4. Restore to test database
gunzip -c /home/ritinder/backups/postgres/${BACKUP_DATE}/n8n.sql.gz | \
  podman exec -i n8n-postgres psql -U n8n -d n8n_restore

# 5. Connect to test database to inspect
podman exec -it n8n-postgres psql -U n8n -d n8n_restore

# 6. Query historical data (example: list workflows)
# SELECT id, name, active, created_at FROM workflow_entity;

# 7. If this is the correct restore point, replace production:
#    a. Export specific data you need
#    b. Or replace entire database (see Scenario 1)

# 8. Clean up test database when done
podman exec n8n-postgres psql -U n8n -d postgres -c "DROP DATABASE n8n_restore;"
```

---

## Disaster Recovery Checklist

### Before Disaster (Preparation)

- [ ] Automated backups enabled (systemd timers)
- [ ] Backups running successfully (check logs)
- [ ] `.env` file backed up securely (encrypted)
- [ ] Backup files tested at least once
- [ ] External backup copy (USB drive, cloud storage)
- [ ] Documentation accessible (printed or on separate device)

### During Disaster (Action Plan)

1. **Assess the situation**
   - What failed? (PostgreSQL, n8n, entire system?)
   - When did it fail? (choose restore point)
   - Are backups accessible?

2. **Choose recovery scenario**
   - Database only → Scenario 1
   - n8n data only → Scenario 2
   - Complete failure → Scenario 3

3. **Execute restore procedure**
   - Follow relevant scenario above
   - Document any issues encountered

4. **Verify restoration**
   - Run health check script
   - Test workflows manually
   - Check recent execution history

5. **Resume operations**
   - Monitor logs for errors
   - Test critical workflows
   - Notify users if needed

---

## Backup Best Practices

### 1. Test Your Backups Regularly

**Monthly test:**
```bash
# Create test restore on separate database
podman exec n8n-postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n_test;"

# Restore latest backup
LATEST_BACKUP=$(ls -t /home/ritinder/backups/postgres/ | head -n1)
gunzip -c /home/ritinder/backups/postgres/${LATEST_BACKUP}/n8n.sql.gz | \
  podman exec -i n8n-postgres psql -U n8n -d n8n_test

# Verify
podman exec n8n-postgres psql -U n8n -d n8n_test -c "\dt"

# Clean up
podman exec n8n-postgres psql -U n8n -d postgres -c "DROP DATABASE n8n_test;"
```

### 2. Keep Off-Site Backups

**Option A: USB Drive / External Storage**
```bash
# Weekly sync to USB drive
rsync -av --delete /home/ritinder/backups/ /mnt/usb/automation-backups/
```

**Option B: Cloud Storage (Planned)**
```bash
# Future: rclone sync to Google Drive
# rclone sync /home/ritinder/backups/ gdrive:automation-backups/
```

### 3. Monitor Backup Success

```bash
# Add to crontab or systemd timer
# Check if backup ran successfully in last 8 hours

#!/bin/bash
LATEST_BACKUP=$(find /home/ritinder/backups/postgres -type d -maxdepth 1 -mmin -480 | wc -l)
if [ $LATEST_BACKUP -eq 0 ]; then
    echo "WARNING: No backup found in last 8 hours!" | mail -s "Backup Alert" admin@example.com
fi
```

### 4. Encrypt Sensitive Backups

```bash
# Encrypt before storing off-site
gpg --symmetric --cipher-algo AES256 /home/ritinder/backups/postgres/*/n8n.sql.gz

# Decrypt when restoring
gpg -d n8n.sql.gz.gpg | podman exec -i n8n-postgres psql -U n8n -d n8n
```

### 5. Document Everything

Keep a restoration log:
```bash
# Create log file
cat > /home/ritinder/backups/RESTORE_LOG.md << 'EOF'
# Restore Log

## 2026-01-14 - Test Restore
- Backup Date: 2026-01-14_120000
- Restore Type: PostgreSQL only
- Result: Success
- Time Taken: 2 minutes
- Notes: All workflows restored correctly

EOF
```

---

## Troubleshooting

### Issue: Backup script fails

**Check:**
```bash
# View script output
bash -x /home/ritinder/developer/automation-stack/backups/scripts/backup_all.sh

# Check disk space
df -h /home/ritinder/backups
```

**Common causes:**
- Disk full
- Container not running
- Permission issues

### Issue: Restore fails with "database does not exist"

**Fix:**
```bash
# Create database first
podman exec n8n-postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n OWNER n8n;"

# Then restore
gunzip -c backup.sql.gz | podman exec -i n8n-postgres psql -U n8n -d n8n
```

### Issue: Backup files corrupted

**Verify backup integrity:**
```bash
# Test gzip file
gunzip -t /home/ritinder/backups/postgres/*/n8n.sql.gz

# Test tar file
tar -tzf /home/ritinder/backups/n8n/*/n8n_data.tar.gz > /dev/null
```

### Issue: Workflows restored but credentials missing

**Cause:** Credentials are encrypted in database. If you restored to different system, encryption key might be different.

**Fix:** Re-enter credentials manually in n8n UI, or ensure `N8N_ENCRYPTION_KEY` is same in `.env` file.

---

## Quick Reference

### Backup Commands
```bash
# Full backup
/home/ritinder/developer/automation-stack/backups/scripts/backup_all.sh

# Check backup status
systemctl --user status automation-backup.timer
journalctl --user -u automation-backup.service -n 20

# List backups
ls -lh /home/ritinder/backups/postgres/
ls -lh /home/ritinder/backups/n8n/
```

### Restore Commands
```bash
# Restore PostgreSQL
gunzip -c /home/ritinder/backups/postgres/TIMESTAMP/n8n.sql.gz | \
  podman exec -i n8n-postgres psql -U n8n -d n8n

# Restore n8n data
podman run --rm -v n8n_data:/restore -v /home/ritinder/backups:/backups:ro \
  alpine tar -xzf /backups/n8n/TIMESTAMP/n8n_data.tar.gz -C /restore --strip-components=1
```

---

## Additional Resources

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [Podman Volume Management](https://docs.podman.io/en/latest/volume.html)
- [n8n Backup Best Practices](https://docs.n8n.io/hosting/configuration/backup/)

---

**Remember:** A backup is only good if you can restore from it. Test regularly!
