# Automation Stack Documentation

Complete implementation guides for your n8n + Python automation stack.

---

## Quick Links

- [Python Runtime Guide](./python-runtime-guide.md) - How to extend the Python FastAPI service
- [n8n Workflow Patterns](./n8n-workflow-patterns.md) - Common workflow patterns and best practices
- [Example Recipes](./example-recipes.md) - Ready-to-use automation recipes

---

## Getting Started

### 1. Your Stack Overview

You have a lightweight, self-hosted automation platform running on Podman:

**Services:**
- **n8n** (192.168.1.9:5678) - Visual workflow orchestration
- **Python Runtime** (localhost:8000) - FastAPI service for custom logic
- **PostgreSQL** (localhost:5434) - Database backend

**Key Features:**
- Custom Node.js modules in n8n: `axios`, `lodash`, `dayjs`, `uuid`
- Python FastAPI ready for extensions
- Automated backups every 6 hours
- Daily maintenance cleanup
- Private network access (LAN + Tailscale)

### 2. Architecture Philosophy

```
┌─────────────────────────────────────────────┐
│                    n8n                      │
│  (Orchestration, Triggers, Visual Flows)   │
└──────────────┬──────────────────────────────┘
               │ HTTP Requests
               ↓
┌─────────────────────────────────────────────┐
│             Python Runtime                  │
│   (Heavy Logic, LLM Calls, Processing)     │
└──────────────┬──────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────┐
│        External Services & APIs             │
│   (OpenAI, Anthropic, Databases, etc.)     │
└─────────────────────────────────────────────┘
```

**Design Principles:**
- n8n handles: Scheduling, triggers, visual workflows, service orchestration
- Python handles: Complex logic, AI/LLM calls, data processing, external integrations
- Communication: HTTP (n8n → Python) and webhooks (Python → n8n)

### 3. First Steps

#### Access n8n
1. Open browser: http://192.168.1.9:5678
2. Login: `admin` / `hello123*`
3. Create your first workflow

#### Test Python Runtime
```bash
# Check health
curl http://127.0.0.1:8000/health

# Should return: {"status":"ok"}
```

#### Test Integration
1. In n8n, create new workflow
2. Add **HTTP Request** node
3. Configure:
   - Method: GET
   - URL: `http://python-runtime:8000/health`
4. Execute
5. Should see: `{"status":"ok"}`

---

## Documentation Guide

### For Beginners

Start here if you're new to n8n or this stack:

1. **Read**: [n8n Workflow Patterns](./n8n-workflow-patterns.md) - Pattern 1 (Simple Request-Response)
2. **Try**: Create a simple workflow that calls Python's `/health` endpoint
3. **Read**: [Python Runtime Guide](./python-runtime-guide.md) - "Basic Endpoint Example"
4. **Try**: Add a simple text processing endpoint
5. **Read**: [Example Recipes](./example-recipes.md) - "Quick Start Template"

### For Intermediate Users

You understand the basics and want to build real automations:

1. **Read**: [n8n Workflow Patterns](./n8n-workflow-patterns.md) - All patterns
2. **Read**: [Python Runtime Guide](./python-runtime-guide.md) - Common Patterns section
3. **Choose**: Pick a recipe from [Example Recipes](./example-recipes.md) that matches your use case
4. **Implement**: Copy the code, customize, deploy
5. **Iterate**: Build more complex workflows

### For Advanced Users

You want to build production-grade automation systems:

1. **Read**: All documentation thoroughly
2. **Architect**: Plan your automation pipeline using the patterns
3. **Extend**: Add custom Python services (LLM clients, data processors)
4. **Optimize**: Implement error handling, retries, monitoring
5. **Scale**: Use async patterns, webhooks, background tasks

---

## Common Use Cases

### 1. AI/LLM Automation

**What you can build:**
- Email summarization
- Content generation
- Document analysis
- Chatbots and assistants
- Sentiment analysis

**Start with:**
- [Python Guide: LLM Integration](./python-runtime-guide.md#pattern-1-llm-integration-openaianthropric)
- [Recipe: AI Email Summarizer](./example-recipes.md#recipe-1-ai-powered-email-summarizer)

### 2. Data Processing

**What you can build:**
- ETL pipelines
- Data enrichment
- Report generation
- Analytics aggregation
- Data validation

**Start with:**
- [Python Guide: Data Processing](./python-runtime-guide.md#pattern-2-data-processing)
- [Workflow Pattern: Batch Processing](./n8n-workflow-patterns.md#pattern-2-batch-processing)

### 3. API Integration & Monitoring

**What you can build:**
- API health monitors
- Multi-service orchestration
- Webhook handlers
- Rate-limited scrapers
- External API wrappers

**Start with:**
- [Python Guide: External API Integration](./python-runtime-guide.md#pattern-3-external-api-integration)
- [Recipe: API Health Monitor](./example-recipes.md#recipe-6-api-health-monitor-with-anomaly-detection)

### 4. Content & Social Media

**What you can build:**
- Content calendars
- Social media schedulers
- Multi-platform posting
- Content analysis
- Engagement tracking

**Start with:**
- [Recipe: Smart Content Calendar](./example-recipes.md#recipe-5-smart-content-calendar)
- [Workflow Pattern: Scheduled Aggregation](./n8n-workflow-patterns.md#pattern-7-scheduled-aggregation)

### 5. Notification & Alerting

**What you can build:**
- Smart alert routing
- Multi-channel notifications
- Priority-based alerting
- Incident management
- Status dashboards

**Start with:**
- [Recipe: Multi-Channel Notifications](./example-recipes.md#recipe-4-multi-channel-notification-system)
- [Workflow Pattern: Event-Driven](./n8n-workflow-patterns.md#pattern-8-event-driven-automation)

---

## Development Workflow

### Adding New Python Functionality

1. **Plan** your endpoint (input, output, logic)
2. **Add dependencies** to `python/requirements.txt` if needed
3. **Write code** in `python/app/` (see [Python Guide](./python-runtime-guide.md))
4. **Rebuild container**:
   ```bash
   cd compose
   podman-compose up -d --build python-runtime
   ```
5. **Test with curl**:
   ```bash
   curl -X POST http://127.0.0.1:8000/your-endpoint \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```
6. **Integrate with n8n** workflow

### Creating n8n Workflows

1. **Design** workflow on paper or whiteboard
2. **Identify** which parts need Python vs n8n built-in nodes
3. **Build** workflow step-by-step in n8n UI
4. **Test** with manual trigger first
5. **Add error handling** (Continue On Fail + IF nodes)
6. **Enable** production trigger (schedule, webhook, etc.)
7. **Monitor** execution history for issues

### Debugging

**Python Issues:**
```bash
# View real-time logs
podman logs -f python-runtime

# Check if container is running
podman ps

# Restart container
cd compose
podman-compose restart python-runtime
```

**n8n Issues:**
- Check **Executions** tab in n8n UI
- Review input/output data for each node
- Enable "Continue On Fail" during development
- Use **Function** nodes to log data

**Integration Issues:**
- Verify URL: Use `http://python-runtime:8000` (not `localhost`)
- Check both containers are on same network: `podman network ls`
- Test Python endpoint directly with curl first
- Review logs from both services

---

## File Structure Reference

```
automation-stack/
├── compose/
│   ├── podman-compose.yml    # Service definitions
│   └── .env                   # Environment variables (not committed)
│
├── n8n/
│   ├── Dockerfile             # Custom n8n image
│   └── package.json           # Node.js dependencies
│
├── python/
│   ├── Dockerfile             # Python image
│   ├── requirements.txt       # Python dependencies
│   └── app/
│       ├── main.py            # FastAPI app
│       ├── routers/           # (Create) API routes
│       │   ├── llm.py
│       │   ├── data.py
│       │   └── scraper.py
│       └── services/          # (Create) Business logic
│           └── openai_service.py
│
├── backups/
│   └── scripts/               # Backup automation
│       ├── backup_all.sh
│       ├── backup_postgres.sh
│       ├── backup_n8n_data.sh
│       └── prune_backups.sh
│
├── maintenance/
│   └── prune_podman.sh        # Cleanup script
│
├── systemd/
│   └── user/                  # Systemd timer files
│       ├── automation-backup.timer
│       ├── automation-backup.service
│       ├── automation-prune.timer
│       └── automation-prune.service
│
└── docs/                      # 📍 You are here
    ├── README.md              # This file
    ├── python-runtime-guide.md
    ├── n8n-workflow-patterns.md
    └── example-recipes.md
```

---

## Environment Variables Reference

### Required Variables (Already Set)

In `compose/.env`:

```bash
# PostgreSQL
POSTGRES_PASSWORD=your_password

# n8n
N8N_HOST=192.168.1.9
N8N_PORT=5678
N8N_SECURE_COOKIE=false
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_password
```

### Optional Variables (Add When Needed)

```bash
# AI/LLM Services
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...

# Notification Services
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# External APIs
WEATHER_API_KEY=...
GOOGLE_API_KEY=...
```

**After adding variables:**
1. Update `compose/podman-compose.yml` to pass them to Python container
2. Restart: `podman-compose restart python-runtime`

---

## Cheat Sheet

### Podman Commands

```bash
# View running containers
podman ps

# View all containers (including stopped)
podman ps -a

# View logs (real-time)
podman logs -f n8n
podman logs -f python-runtime
podman logs -f n8n-postgres

# Restart a service
cd compose
podman-compose restart n8n
podman-compose restart python-runtime

# Rebuild after code changes
podman-compose up -d --build python-runtime

# Stop all services
podman-compose down

# Start all services
podman-compose up -d

# Execute command in container
podman exec -it python-runtime bash
podman exec -it n8n sh
```

### Testing Endpoints

```bash
# Health check
curl http://127.0.0.1:8000/health

# POST with JSON
curl -X POST http://127.0.0.1:8000/endpoint \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'

# View response headers
curl -i http://127.0.0.1:8000/health

# Save response to file
curl http://127.0.0.1:8000/endpoint > response.json
```

### n8n Tips

```bash
# Access n8n
http://192.168.1.9:5678

# Call Python from n8n
http://python-runtime:8000/your-endpoint

# Access from outside workflow (manual testing)
http://127.0.0.1:8000/your-endpoint
```

### Backup & Maintenance

```bash
# Manual backup
/home/ritinder/developer/automation-stack/backups/scripts/backup_all.sh

# Check backup timer status
systemctl --user list-timers

# View backup logs
journalctl --user -u automation-backup.service
```

---

## Troubleshooting Guide

### Issue: n8n won't start

**Check:**
```bash
podman logs n8n
```

**Common causes:**
- PostgreSQL not ready yet (wait 10 seconds, retry)
- Database connection error (check `.env` password)
- Port already in use

### Issue: Python container crashes

**Check:**
```bash
podman logs python-runtime
```

**Common causes:**
- Syntax error in Python code
- Missing dependency in `requirements.txt`
- Import error

**Fix:**
1. Fix the code
2. Rebuild: `podman-compose up -d --build python-runtime`

### Issue: n8n can't reach Python

**Symptoms:** HTTP Request node times out or fails

**Check:**
1. Both containers running: `podman ps`
2. Python is healthy: `curl http://127.0.0.1:8000/health`
3. Using correct URL in n8n: `http://python-runtime:8000` (not localhost)

### Issue: Changes not reflecting

**Python code changes:**
```bash
cd compose
podman-compose restart python-runtime
```

**If that doesn't work:**
```bash
podman-compose up -d --build python-runtime
```

**New dependencies:**
```bash
# Edit requirements.txt first, then:
podman-compose up -d --build python-runtime
```

### Issue: Out of disk space

**Check usage:**
```bash
df -h
podman system df
```

**Clean up:**
```bash
# Prune unused resources
/home/ritinder/developer/automation-stack/maintenance/prune_podman.sh

# Remove old backups
find /home/ritinder/backups -type d -mtime +7 -exec rm -rf {} +
```

---

## Next Steps

### Immediate Actions

1. ✅ n8n is running
2. ✅ Python runtime is healthy
3. ✅ Integration tested
4. ⏳ Set up systemd timers for automated backups
5. ⏳ Create your first real workflow

### Short Term (This Week)

1. Pick a recipe from [Example Recipes](./example-recipes.md)
2. Implement it step-by-step
3. Test thoroughly
4. Document any custom endpoints you add

### Medium Term (This Month)

1. Build 3-5 production workflows
2. Add LLM integration (OpenAI or Anthropic)
3. Set up monitoring and alerting
4. Create workflow templates for common patterns

### Long Term

1. Explore n8n community nodes
2. Add more Python services (web scraping, data processing)
3. Integrate with more external services
4. Consider cloud backup sync
5. Optional: Add TLS/HTTPS
6. Optional: Enable Hook0 for advanced webhook management

---

## Additional Resources

### Official Documentation

- [n8n Documentation](https://docs.n8n.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Podman Documentation](https://docs.podman.io/)

### Community

- [n8n Community Forum](https://community.n8n.io/)
- [n8n Workflows Library](https://n8n.io/workflows/)

### Learning Resources

- n8n YouTube Channel - Tutorial videos
- FastAPI Tutorial - Build REST APIs
- Python httpx - Async HTTP client library

---

## Support

For issues with this stack:
1. Check logs: `podman logs <container-name>`
2. Review relevant guide in this documentation
3. Test components individually (Python endpoint → n8n workflow)
4. Check environment variables are set correctly

---

**Ready to build?** Start with [Example Recipes](./example-recipes.md) and pick your first automation project!

🚀 Happy automating!
