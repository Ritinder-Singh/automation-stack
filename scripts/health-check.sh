#!/bin/bash

# =============================================================================
# Health Check Script for Automation Stack
# =============================================================================
# Verifies all services are running and responding correctly
# Usage: ./health-check.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Automation Stack Health Check${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Check Podman containers
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/6] Checking Podman containers...${NC}"

containers=("n8n-postgres" "n8n" "python-runtime")

for container in "${containers[@]}"; do
    if podman ps --format "{{.Names}}" | grep -q "^${container}$"; then
        status=$(podman inspect --format='{{.State.Status}}' "$container")
        if [ "$status" = "running" ]; then
            echo -e "  ${GREEN}✓${NC} $container is running"
        else
            echo -e "  ${RED}✗${NC} $container exists but status: $status"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "  ${RED}✗${NC} $container is not running"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""

# -----------------------------------------------------------------------------
# 2. Check PostgreSQL
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/6] Checking PostgreSQL...${NC}"

if podman exec n8n-postgres pg_isready -U n8n -d n8n > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} PostgreSQL is accepting connections"
else
    echo -e "  ${RED}✗${NC} PostgreSQL is not responding"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Check Python Runtime
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/6] Checking Python Runtime...${NC}"

if curl -f -s http://127.0.0.1:8000/health > /dev/null 2>&1; then
    response=$(curl -s http://127.0.0.1:8000/health)
    if echo "$response" | grep -q '"status":"ok"'; then
        echo -e "  ${GREEN}✓${NC} Python runtime is healthy"
    else
        echo -e "  ${YELLOW}⚠${NC} Python runtime responded but status unknown"
        echo -e "    Response: $response"
    fi
else
    echo -e "  ${RED}✗${NC} Python runtime is not responding at localhost:8000"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 4. Check n8n
# -----------------------------------------------------------------------------
echo -e "${BLUE}[4/6] Checking n8n...${NC}"

# Try to reach n8n (will return 401 if auth is enabled, which is fine)
if curl -f -s -o /dev/null -w "%{http_code}" http://192.168.1.9:5678 | grep -qE "^(200|401)$"; then
    echo -e "  ${GREEN}✓${NC} n8n is responding on 192.168.1.9:5678"
else
    echo -e "  ${RED}✗${NC} n8n is not responding on 192.168.1.9:5678"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Check volumes
# -----------------------------------------------------------------------------
echo -e "${BLUE}[5/6] Checking Podman volumes...${NC}"

volumes=("n8n_postgres_data" "n8n_data" "python_data")

for volume in "${volumes[@]}"; do
    if podman volume exists "$volume" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Volume $volume exists"
    else
        echo -e "  ${YELLOW}⚠${NC} Volume $volume does not exist (will be created on first run)"
    fi
done

echo ""

# -----------------------------------------------------------------------------
# 6. Check backup infrastructure
# -----------------------------------------------------------------------------
echo -e "${BLUE}[6/6] Checking backup infrastructure...${NC}"

# Check backup directory
if [ -d "/home/ritinder/backups" ]; then
    echo -e "  ${GREEN}✓${NC} Backup directory exists"
else
    echo -e "  ${YELLOW}⚠${NC} Backup directory does not exist"
    echo -e "    Run: mkdir -p /home/ritinder/backups/{postgres,n8n}"
fi

# Check backup scripts are executable
backup_scripts=(
    "/home/ritinder/developer/automation-stack/backups/scripts/backup_all.sh"
    "/home/ritinder/developer/automation-stack/backups/scripts/backup_postgres.sh"
    "/home/ritinder/developer/automation-stack/backups/scripts/backup_n8n_data.sh"
)

all_executable=true
for script in "${backup_scripts[@]}"; do
    if [ -x "$script" ]; then
        : # Script is executable, no output needed
    else
        all_executable=false
    fi
done

if [ "$all_executable" = true ]; then
    echo -e "  ${GREEN}✓${NC} Backup scripts are executable"
else
    echo -e "  ${YELLOW}⚠${NC} Some backup scripts are not executable"
fi

# Check systemd timers
if systemctl --user is-enabled automation-backup.timer > /dev/null 2>&1; then
    if systemctl --user is-active automation-backup.timer > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Backup timer is enabled and active"
    else
        echo -e "  ${YELLOW}⚠${NC} Backup timer is enabled but not active"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Backup timer is not enabled"
    echo -e "    See: docs/README.md for installation instructions"
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}==============================================================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "Your automation stack is healthy and ready to use."
    echo ""
    echo -e "Access n8n: ${BLUE}http://192.168.1.9:5678${NC}"
    echo -e "Python API: ${BLUE}http://127.0.0.1:8000${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo -e "Please review the output above and fix any issues."
    echo ""
    echo "Common fixes:"
    echo "  - Start services: cd compose && podman-compose up -d"
    echo "  - Check logs: podman logs <container-name>"
    echo "  - Rebuild: cd compose && podman-compose up -d --build"
    exit 1
fi
