# Python Runtime Implementation Guide

This guide shows how to extend the Python FastAPI runtime and integrate it with n8n workflows.

---

## Architecture Overview

```
n8n Workflow → HTTP Request → Python FastAPI → External APIs/Services
                    ↓
              Python Processing
                    ↓
              Return Response → n8n continues workflow
```

**Key Principles:**
- Python runtime handles heavy logic, LLM calls, data processing
- n8n orchestrates and schedules
- Communication via HTTP (n8n → Python) and webhooks (Python → n8n)

---

## Table of Contents

1. [Adding New Endpoints](#adding-new-endpoints)
2. [Calling Python from n8n](#calling-python-from-n8n)
3. [Common Patterns](#common-patterns)
4. [Deploying Changes](#deploying-changes)
5. [Examples](#examples)

---

## Adding New Endpoints

### File Structure

```
python/
├── Dockerfile
├── requirements.txt
└── app/
    ├── main.py          # Main FastAPI app
    ├── routers/         # (Create this) Route modules
    │   ├── __init__.py
    │   ├── llm.py
    │   └── data.py
    └── services/        # (Create this) Business logic
        ├── __init__.py
        └── openai_service.py
```

### Basic Endpoint Example

**Edit:** `python/app/main.py`

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Automation Python Runtime")


# Health check (already exists)
@app.get("/health")
async def health():
    return {"status": "ok"}


# Simple data processing endpoint
class ProcessRequest(BaseModel):
    text: str
    action: str  # "uppercase", "lowercase", "reverse"


@app.post("/process-text")
async def process_text(request: ProcessRequest):
    """
    Process text based on action type
    """
    text = request.text

    if request.action == "uppercase":
        result = text.upper()
    elif request.action == "lowercase":
        result = text.lower()
    elif request.action == "reverse":
        result = text[::-1]
    else:
        raise HTTPException(status_code=400, detail="Invalid action")

    return {
        "original": text,
        "processed": result,
        "action": request.action
    }
```

**Rebuild and deploy:**
```bash
cd /home/ritinder/developer/automation-stack/compose
podman-compose up -d --build python-runtime
```

---

## Calling Python from n8n

### Method 1: HTTP Request Node (Synchronous)

**Best for:** Quick operations (< 30 seconds)

1. In n8n, add an **HTTP Request** node
2. Configure:
   - **Method:** POST
   - **URL:** `http://python-runtime:8000/process-text`
   - **Body Content Type:** JSON
   - **JSON Body:**
     ```json
     {
       "text": "{{ $json.input_text }}",
       "action": "uppercase"
     }
     ```

3. Response will be available in `$json` for next node

### Method 2: Webhook Pattern (Asynchronous)

**Best for:** Long-running operations (> 30 seconds)

**Python endpoint:**
```python
import httpx
from fastapi import BackgroundTasks

@app.post("/long-task")
async def long_task(
    data: dict,
    background_tasks: BackgroundTasks
):
    """
    Start long task and notify n8n via webhook when done
    """
    task_id = str(uuid.uuid4())
    callback_url = data.get("callback_url")

    # Start background task
    background_tasks.add_task(
        process_long_task,
        task_id,
        data,
        callback_url
    )

    return {
        "task_id": task_id,
        "status": "started"
    }


async def process_long_task(task_id: str, data: dict, callback_url: str):
    """
    Process long task and call back to n8n
    """
    # Do heavy processing here
    result = {"task_id": task_id, "result": "completed"}

    # Notify n8n via webhook
    if callback_url:
        async with httpx.AsyncClient() as client:
            await client.post(callback_url, json=result)
```

**n8n workflow:**
1. **Webhook** node (trigger) - Copy webhook URL
2. **HTTP Request** node - Call Python with `callback_url` parameter
3. Workflow continues when webhook receives callback

---

## Common Patterns

### Pattern 1: LLM Integration (OpenAI/Anthropic)

**Add dependency:**

Edit `python/requirements.txt`:
```
fastapi
uvicorn[standard]
httpx
openai
anthropic
```

**Python endpoint:**

Create `python/app/routers/llm.py`:
```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from anthropic import Anthropic
import os

router = APIRouter(prefix="/llm", tags=["llm"])

class ChatRequest(BaseModel):
    prompt: str
    system: str = "You are a helpful assistant"
    max_tokens: int = 1024


@router.post("/claude")
async def chat_claude(request: ChatRequest):
    """
    Call Anthropic Claude API
    """
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="API key not configured")

    client = Anthropic(api_key=api_key)

    message = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=request.max_tokens,
        system=request.system,
        messages=[
            {"role": "user", "content": request.prompt}
        ]
    )

    return {
        "response": message.content[0].text,
        "model": message.model,
        "usage": {
            "input_tokens": message.usage.input_tokens,
            "output_tokens": message.usage.output_tokens
        }
    }
```

**Update** `python/app/main.py`:
```python
from fastapi import FastAPI
from app.routers import llm

app = FastAPI(title="Automation Python Runtime")

# Include routers
app.include_router(llm.router)

@app.get("/health")
async def health():
    return {"status": "ok"}
```

**Add API key to .env:**
```bash
# In compose/.env
ANTHROPIC_API_KEY=your_key_here
```

**Update podman-compose.yml:**
```yaml
  python-runtime:
    # ... existing config ...
    environment:
      PYTHONUNBUFFERED: "1"
      TZ: UTC
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
```

---

### Pattern 2: Data Processing

**Example: Parse and transform data**

```python
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict

router = APIRouter(prefix="/data", tags=["data"])

class DataTransformRequest(BaseModel):
    items: List[Dict]
    operations: List[str]  # ["filter_empty", "dedupe", "sort"]


@router.post("/transform")
async def transform_data(request: DataTransformRequest):
    """
    Apply transformations to data array
    """
    items = request.items

    for op in request.operations:
        if op == "filter_empty":
            items = [item for item in items if item.get("value")]
        elif op == "dedupe":
            seen = set()
            deduped = []
            for item in items:
                key = item.get("id")
                if key not in seen:
                    seen.add(key)
                    deduped.append(item)
            items = deduped
        elif op == "sort":
            items = sorted(items, key=lambda x: x.get("value", ""))

    return {
        "items": items,
        "count": len(items)
    }
```

---

### Pattern 3: External API Integration

**Example: Weather API wrapper**

```python
import httpx
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/external", tags=["external"])

@router.get("/weather/{city}")
async def get_weather(city: str):
    """
    Fetch weather data from external API
    """
    api_key = os.getenv("WEATHER_API_KEY")

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "appid": api_key, "units": "metric"}
        )

        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail="API error")

        data = response.json()
        return {
            "city": city,
            "temperature": data["main"]["temp"],
            "description": data["weather"][0]["description"],
            "humidity": data["main"]["humidity"]
        }
```

---

### Pattern 4: File Processing

**With persistent storage:**

```python
from fastapi import APIRouter, UploadFile, File
import json
from pathlib import Path

router = APIRouter(prefix="/files", tags=["files"])

DATA_DIR = Path("/app/data")
DATA_DIR.mkdir(exist_ok=True)


@router.post("/save")
async def save_file(file: UploadFile = File(...)):
    """
    Save uploaded file to persistent volume
    """
    file_path = DATA_DIR / file.filename

    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)

    return {
        "filename": file.filename,
        "size": len(content),
        "path": str(file_path)
    }


@router.get("/list")
async def list_files():
    """
    List all files in data directory
    """
    files = []
    for file_path in DATA_DIR.iterdir():
        if file_path.is_file():
            files.append({
                "name": file_path.name,
                "size": file_path.stat().st_size
            })
    return {"files": files}
```

---

## Deploying Changes

### 1. Code Changes Only

```bash
cd /home/ritinder/developer/automation-stack/compose
podman-compose restart python-runtime
```

**Note:** Only works if you're editing code in real-time (mounted volume). For baked-in changes, rebuild.

### 2. New Dependencies

**After editing `requirements.txt`:**
```bash
cd /home/ritinder/developer/automation-stack/compose
podman-compose up -d --build python-runtime
```

### 3. Full Stack Rebuild

```bash
cd /home/ritinder/developer/automation-stack/compose
podman-compose down
podman-compose up -d --build
```

### 4. View Logs

```bash
# Real-time logs
podman logs -f python-runtime

# Last 50 lines
podman logs --tail 50 python-runtime
```

---

## Examples

### Example 1: Text Summarization with Claude

**Python:** Add to `llm.py`:
```python
@router.post("/summarize")
async def summarize_text(text: str, max_length: int = 100):
    client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

    message = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=max_length,
        messages=[{
            "role": "user",
            "content": f"Summarize this in {max_length} words:\n\n{text}"
        }]
    )

    return {"summary": message.content[0].text}
```

**n8n Workflow:**
1. **Schedule Trigger** - Daily at 9 AM
2. **HTTP Request** - Fetch news articles
3. **Split In Batches** - Process one at a time
4. **HTTP Request** - Call `http://python-runtime:8000/llm/summarize`
5. **Send Email** - Send daily digest

---

### Example 2: Data Pipeline

**n8n Workflow:**
1. **Webhook** - Receive data from external service
2. **HTTP Request** to Python - `/data/transform`
3. **Split In Batches**
4. For each item:
   - **HTTP Request** to Python - `/external/enrich`
   - **HTTP Request** - Save to database
5. **Aggregate** results
6. **HTTP Request** - Send to Python for analysis
7. **Send Notification**

---

## Testing Endpoints

### Using curl

```bash
# Health check
curl http://127.0.0.1:8000/health

# Test text processing
curl -X POST http://127.0.0.1:8000/process-text \
  -H "Content-Type: application/json" \
  -d '{"text": "hello world", "action": "uppercase"}'

# Test LLM endpoint (from Raspberry Pi)
curl -X POST http://127.0.0.1:8000/llm/claude \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is the capital of France?",
    "max_tokens": 100
  }'
```

### From n8n

Use **HTTP Request** node with URL: `http://python-runtime:8000/your-endpoint`

---

## Best Practices

1. **Use Pydantic models** for request/response validation
2. **Break logic into modules** (routers, services)
3. **Handle errors gracefully** with try/except and HTTPException
4. **Use environment variables** for secrets (never hardcode)
5. **Log important operations** using Python logging
6. **Keep endpoints focused** - one responsibility per endpoint
7. **Use async/await** for I/O operations (API calls, database)
8. **Test locally first** with curl before integrating with n8n

---

## Troubleshooting

**Python container won't start:**
```bash
podman logs python-runtime
```
Usually a syntax error or missing dependency.

**n8n can't reach Python:**
- Use `http://python-runtime:8000` (container name, not localhost)
- Check both containers are running: `podman ps`

**Endpoint returns 500 error:**
- Check Python logs: `podman logs python-runtime`
- Verify environment variables are set in podman-compose.yml

**Changes not reflecting:**
- Rebuild: `podman-compose up -d --build python-runtime`
- Clear browser cache if testing from n8n UI

---

## Next Steps

1. Start with simple endpoints (text processing)
2. Add LLM integration when needed
3. Build reusable services in `/services` directory
4. Create n8n workflow templates for common patterns
5. Document your custom endpoints in this file

---

Happy automating! 🚀
