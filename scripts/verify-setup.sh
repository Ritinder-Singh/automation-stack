#!/bin/bash

# =============================================================================
# Setup Verification Script for Automation Stack
# =============================================================================
# Verifies that all prerequisites and configurations are correct
# Run this BEFORE starting the stack for the first time
# Usage: ./verify-setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Automation Stack Setup Verification${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Check Prerequisites
# -----------------------------------------------------------------------------
echo -e "${BLUE}[1/7] Checking prerequisites...${NC}"

# Check Podman
if command -v podman &> /dev/null; then
    version=$(podman --version | awk '{print $3}')
    echo -e "  ${GREEN}✓${NC} Podman installed: $version"
else
    echo -e "  ${RED}✗${NC} Podman is not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check podman-compose
if command -v podman-compose &> /dev/null; then
    version=$(podman-compose --version 2>&1 | head -n1)
    echo -e "  ${GREEN}✓${NC} podman-compose installed: $version"
else
    echo -e "  ${RED}✗${NC} podman-compose is not installed"
    echo -e "    Install: pip3 install podman-compose"
    ERRORS=$((ERRORS + 1))
fi

# Check curl
if command -v curl &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} curl is installed"
else
    echo -e "  ${YELLOW}⚠${NC} curl is not installed (needed for health checks)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Check Directory Structure
# -----------------------------------------------------------------------------
echo -e "${BLUE}[2/7] Checking directory structure...${NC}"

base_dir="/home/ritinder/developer/automation-stack"

required_dirs=(
    "$base_dir/compose"
    "$base_dir/n8n"
    "$base_dir/python"
    "$base_dir/python/app"
    "$base_dir/backups/scripts"
    "$base_dir/maintenance"
    "$base_dir/systemd/user"
    "$base_dir/docs"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $dir"
    else
        echo -e "  ${RED}✗${NC} $dir is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""

# -----------------------------------------------------------------------------
# 3. Check Required Files
# -----------------------------------------------------------------------------
echo -e "${BLUE}[3/7] Checking required files...${NC}"

required_files=(
    "$base_dir/compose/podman-compose.yml"
    "$base_dir/compose/.env"
    "$base_dir/n8n/Dockerfile"
    "$base_dir/n8n/package.json"
    "$base_dir/python/Dockerfile"
    "$base_dir/python/requirements.txt"
    "$base_dir/python/app/main.py"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} ${file##*/}"
    else
        echo -e "  ${RED}✗${NC} $file is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""

# -----------------------------------------------------------------------------
# 4. Check Environment Variables
# -----------------------------------------------------------------------------
echo -e "${BLUE}[4/7] Checking environment variables...${NC}"

env_file="$base_dir/compose/.env"

if [ -f "$env_file" ]; then
    required_vars=(
        "POSTGRES_PASSWORD"
        "N8N_HOST"
        "N8N_PORT"
        "N8N_SECURE_COOKIE"
        "N8N_BASIC_AUTH_USER"
        "N8N_BASIC_AUTH_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" "$env_file"; then
            value=$(grep "^${var}=" "$env_file" | cut -d'=' -f2)
            if [ -n "$value" ]; then
                echo -e "  ${GREEN}✓${NC} $var is set"
            else
                echo -e "  ${YELLOW}⚠${NC} $var is defined but empty"
                WARNINGS=$((WARNINGS + 1))
            fi
        else
            echo -e "  ${RED}✗${NC} $var is not defined"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # Check for default passwords
    if grep -q "N8N_BASIC_AUTH_PASSWORD=hello123\*" "$env_file"; then
        echo -e "  ${YELLOW}⚠${NC} Using default n8n password (consider changing)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  ${RED}✗${NC} .env file is missing"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Check podman-compose.yml Configuration
# -----------------------------------------------------------------------------
echo -e "${BLUE}[5/7] Checking podman-compose.yml...${NC}"

compose_file="$base_dir/compose/podman-compose.yml"

if [ -f "$compose_file" ]; then
    # Check services are defined
    services=("postgres" "n8n" "python-runtime")
    for service in "${services[@]}"; do
        if grep -q "^  ${service}:" "$compose_file"; then
            echo -e "  ${GREEN}✓${NC} Service '$service' is defined"
        else
            echo -e "  ${RED}✗${NC} Service '$service' is missing"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # Check volumes are defined
    if grep -q "^volumes:" "$compose_file"; then
        echo -e "  ${GREEN}✓${NC} Volumes section exists"
    else
        echo -e "  ${YELLOW}⚠${NC} Volumes section is missing"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check N8N_SECURE_COOKIE is set in compose file
    if grep -q "N8N_SECURE_COOKIE" "$compose_file"; then
        echo -e "  ${GREEN}✓${NC} N8N_SECURE_COOKIE is configured"
    else
        echo -e "  ${YELLOW}⚠${NC} N8N_SECURE_COOKIE not found in compose file"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  ${RED}✗${NC} podman-compose.yml is missing"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 6. Check Backup Infrastructure
# -----------------------------------------------------------------------------
echo -e "${BLUE}[6/7] Checking backup infrastructure...${NC}"

# Check backup directory
backup_dir="/home/ritinder/backups"
if [ ! -d "$backup_dir" ]; then
    echo -e "  ${YELLOW}⚠${NC} Backup directory does not exist"
    echo -e "    Creating: $backup_dir/{postgres,n8n}"
    mkdir -p "$backup_dir/postgres" "$backup_dir/n8n" 2>/dev/null && \
        echo -e "    ${GREEN}✓${NC} Created backup directories" || \
        echo -e "    ${RED}✗${NC} Failed to create backup directories"
else
    echo -e "  ${GREEN}✓${NC} Backup directory exists"

    # Check subdirectories
    if [ -d "$backup_dir/postgres" ] && [ -d "$backup_dir/n8n" ]; then
        echo -e "  ${GREEN}✓${NC} Backup subdirectories exist"
    else
        echo -e "  ${YELLOW}⚠${NC} Creating backup subdirectories"
        mkdir -p "$backup_dir/postgres" "$backup_dir/n8n" 2>/dev/null && \
            echo -e "    ${GREEN}✓${NC} Created backup subdirectories" || \
            echo -e "    ${RED}✗${NC} Failed to create backup subdirectories"
    fi
fi

# Check backup scripts
backup_scripts=(
    "$base_dir/backups/scripts/backup_all.sh"
    "$base_dir/backups/scripts/backup_postgres.sh"
    "$base_dir/backups/scripts/backup_n8n_data.sh"
    "$base_dir/backups/scripts/prune_backups.sh"
)

all_executable=true
for script in "${backup_scripts[@]}"; do
    if [ ! -x "$script" ]; then
        all_executable=false
        break
    fi
done

if [ "$all_executable" = true ]; then
    echo -e "  ${GREEN}✓${NC} All backup scripts are executable"
else
    echo -e "  ${YELLOW}⚠${NC} Some backup scripts are not executable"
    echo -e "    Fix: chmod +x $base_dir/backups/scripts/*.sh"
fi

# Check maintenance script
if [ -x "$base_dir/maintenance/prune_podman.sh" ]; then
    echo -e "  ${GREEN}✓${NC} Maintenance script is executable"
else
    echo -e "  ${YELLOW}⚠${NC} Maintenance script is not executable"
    echo -e "    Fix: chmod +x $base_dir/maintenance/*.sh"
fi

# Check systemd timers
timer_dir="$HOME/.config/systemd/user"
if [ -d "$timer_dir" ]; then
    if [ -f "$timer_dir/automation-backup.timer" ]; then
        echo -e "  ${GREEN}✓${NC} Systemd timers are installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Systemd timers are not installed"
        echo -e "    See: docs/README.md for installation instructions"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Systemd user directory does not exist"
    echo -e "    Timers need to be installed manually"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# 7. Check Network Configuration
# -----------------------------------------------------------------------------
echo -e "${BLUE}[7/7] Checking network configuration...${NC}"

# Check if IP 192.168.1.9 is configured
if ip addr | grep -q "192.168.1.9"; then
    echo -e "  ${GREEN}✓${NC} IP 192.168.1.9 is configured on this machine"
else
    echo -e "  ${YELLOW}⚠${NC} IP 192.168.1.9 not found on this machine"
    echo -e "    Current IPs:"
    ip -4 addr show | grep inet | awk '{print "    " $2}' | head -n 5
    echo -e "    ${YELLOW}Note:${NC} Update N8N_HOST in .env if using different IP"
    WARNINGS=$((WARNINGS + 1))
fi

# Check if port 5678 is available
if ! ss -tuln 2>/dev/null | grep -q ":5678 "; then
    echo -e "  ${GREEN}✓${NC} Port 5678 is available (n8n)"
else
    echo -e "  ${YELLOW}⚠${NC} Port 5678 is already in use"
    WARNINGS=$((WARNINGS + 1))
fi

# Check if port 8000 is available
if ! ss -tuln 2>/dev/null | grep -q ":8000 "; then
    echo -e "  ${GREEN}✓${NC} Port 8000 is available (Python)"
else
    echo -e "  ${YELLOW}⚠${NC} Port 8000 is already in use"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your automation stack is ready to deploy."
    echo ""
    echo "Next steps:"
    echo "  1. cd compose"
    echo "  2. podman-compose up -d --build"
    echo "  3. Wait 10-15 seconds for services to start"
    echo "  4. Run: ../scripts/health-check.sh"
    echo "  5. Access n8n: http://192.168.1.9:5678"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Found $WARNINGS warning(s)${NC}"
    echo ""
    echo "Your stack should work, but you may want to address the warnings above."
    echo ""
    echo "You can proceed with deployment:"
    echo "  cd compose && podman-compose up -d --build"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before deploying."
    echo ""
    echo "Common fixes:"
    echo "  - Install missing packages: sudo apt install <package>"
    echo "  - Create .env file: cp compose/.env.example compose/.env"
    echo "  - Make scripts executable: chmod +x backups/scripts/*.sh"
    echo ""
    exit 1
fi
