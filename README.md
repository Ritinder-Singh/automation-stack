# Automation Stack (Raspberry Pi)

This repository contains a **self-hosted automation and experimentation stack** running on a Raspberry Pi using **Podman + podman-compose**.

The stack is designed for:
- automation
- learning & experimentation
- API and LLM workflows
- non-invasive CI/CD integration
- long-term maintainability

This is **not** an enterprise production setup. The focus is on clarity, control, reproducibility, and ease of extension.

---

## High-level architecture

External Services
│
▼
(Hook0) ← optional, disabled by default
│
▼
n8n ← orchestration & workflows
│
▼
Python Runtime ← compute, async tasks, integrations
│
▼
PostgreSQL ← n8n persistence


---

## Core components

### n8n
- Workflow automation engine
- Custom Node.js image (modules baked in)
- Used for orchestration, triggers, APIs, and control flow
- Accessed privately (via Tailscale)

### Python Runtime
- Single container, single Dockerfile
- Hosts multiple Python services via HTTP
- Supports async background tasks
- Used for:
  - API integrations
  - data processing
  - experimentation
  - LLM-related workloads

### PostgreSQL
- Dedicated database for n8n
- Stores:
  - workflows
  - credentials
  - execution history
- Uses retention policies (no separate historic DB yet)

### Hook0 (optional)
- Webhook gateway and event control plane
- Included in the design
- **Disabled by default**
- Can be enabled later without redesign

### Backups
- Local SSD backups
- Scheduled every 6–8 hours
- Covers:
  - n8n PostgreSQL data
  - n8n persistent data
  - environment configuration
- Cloud backups can be added later

---

## Security & access model

- **Inbound access**
  - Private only (via Tailscale)
  - No public internet exposure
  - No reverse proxy or TLS complexity

- **Outbound access**
  - Full internet access for APIs, LLMs, and integrations

- **Secrets**
  - Stored in a single `.env` file
  - Never committed to Git
  - Easy to rotate and back up

---

## Design principles

- Podman over Docker (lighter, daemonless)
- podman-compose for service orchestration
- Explicit resource limits for stability
- Healthchecks for all core services
- Log size limits and rotation
- Conservative cleanup and pruning
- Clear separation from existing CI/CD stack
- Fully reproducible setup

---

## Repository structure

automation-stack/
├── compose/ # podman-compose files and env
├── n8n/ # n8n custom image
├── python/ # Python runtime services
├── postgres/ # PostgreSQL notes and volumes
├── hook0/ # Hook0 placeholder (disabled)
├── backups/ # Backup scripts and docs
└── README.md


---

## What this repo intentionally does NOT include

- Kubernetes
- Reverse proxy / ingress
- Public exposure
- Multi-tenant auth
- Enterprise monitoring stacks
- Premature optimization

These can be added later **only if needed**.

---

## Status

- [x] Architecture finalized
- [x] Security and stability safeguards planned
- [x] Directory structure created
- [ ] podman-compose.yml
- [ ] PostgreSQL service
- [ ] n8n service
- [ ] Python runtime
- [ ] Backup automation
- [ ] Hook0 enablement (optional)

---

## Notes

This stack coexists with an existing CI/CD setup on the same Raspberry Pi.  
It does **not** replace Jenkins or existing deployment pipelines.

---

## How to proceed

The stack is built **incrementally**:

1. Design
2. Review
3. Implement
4. Test

Nothing is started automatically until explicitly enabled.

---

