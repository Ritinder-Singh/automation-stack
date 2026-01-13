# Scripts Directory

Utility scripts for managing and monitoring your automation stack.

---

## Available Scripts

### 1. verify-setup.sh

**Purpose:** Verify that all prerequisites and configurations are correct before first deployment

**When to use:** Run BEFORE starting the stack for the first time, or after making configuration changes

**What it checks:**
- Prerequisites installed (Podman, podman-compose, curl)
- Directory structure is correct
- Required files exist
- Environment variables are set in .env
- podman-compose.yml is properly configured
- Backup infrastructure is ready
- Network configuration (IP address, ports)

**Usage:**
```bash
cd /home/ritinder/developer/automation-stack/scripts
./verify-setup.sh
```

**Exit codes:**
- `0`: All checks passed, ready to deploy
- `1`: Errors found, fix before deploying

---

### 2. health-check.sh

**Purpose:** Verify that all services are running and responding correctly

**When to use:**
- After starting services
- For routine monitoring
- When troubleshooting issues
- Before making changes

**What it checks:**
- All containers are running
- PostgreSQL is accepting connections
- Python runtime is responding
- n8n is accessible
- Podman volumes exist
- Backup infrastructure is configured
- Systemd timers are active

**Usage:**
```bash
cd /home/ritinder/developer/automation-stack/scripts
./health-check.sh
```

**Exit codes:**
- `0`: All services healthy
- `1`: Issues detected

---

## Installation

Make scripts executable:
```bash
chmod +x /home/ritinder/developer/automation-stack/scripts/*.sh
```

---

## Typical Workflow

### First-Time Setup

1. Clone/create automation stack
2. Configure `.env` file
3. **Run verify-setup.sh** to check everything
4. Fix any errors reported
5. Deploy: `cd compose && podman-compose up -d --build`
6. **Run health-check.sh** to verify deployment

### Routine Monitoring

Add to crontab for periodic checks:
```bash
# Check health every hour
0 * * * * /home/ritinder/developer/automation-stack/scripts/health-check.sh
```

Or create a systemd timer (similar to backup timers).

### After Changes

1. Make configuration changes
2. **Run verify-setup.sh** to validate
3. Restart services
4. **Run health-check.sh** to verify

### Troubleshooting

When something isn't working:
1. **Run health-check.sh** to identify the problem
2. Check logs: `podman logs <container-name>`
3. Fix the issue
4. **Run health-check.sh** again to confirm fix

---

## Future Scripts (Planned)

- `update-stack.sh` - Update images and redeploy
- `export-config.sh` - Export configuration for backup
- `monitor.sh` - Continuous monitoring with alerts
- `migrate.sh` - Migrate to new server

---

## Adding Custom Scripts

To add your own utility scripts:

1. Create script in this directory
2. Make it executable: `chmod +x your-script.sh`
3. Add documentation here
4. Use consistent naming: `verb-noun.sh` (e.g., `check-logs.sh`)

---

## Related Documentation

- [Main README](../docs/README.md) - Setup and usage guide
- [Backup & Restore Guide](../docs/backup-restore-guide.md) - Backup procedures
- [Python Runtime Guide](../docs/python-runtime-guide.md) - Python development
- [n8n Workflow Patterns](../docs/n8n-workflow-patterns.md) - Workflow design
