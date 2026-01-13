# Backups

This directory contains local backup scripts for the automation stack.

## What is backed up

- PostgreSQL (n8n database)
- n8n user data (workflows, credentials, executions)

## Backup location (runtime)

Backups are written to:

/backups/
├── postgres/
└── n8n/


This should be mounted to the SSD on the Raspberry Pi.

## Retention

- Default: 7 days
- Configurable in `prune_backups.sh`

## Restore (high-level)

1. Stop services
2. Restore Postgres dump
3. Restore n8n volume
4. Restart services