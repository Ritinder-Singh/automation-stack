# Example Recipes

Ready-to-use code examples for common automation scenarios.

---

## Recipe 1: AI-Powered Email Summarizer

**Use case:** Summarize long emails using Claude AI

### Python Code

Add to `python/app/routers/llm.py`:

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from anthropic import Anthropic
import os

router = APIRouter(prefix="/llm", tags=["llm"])

class EmailSummaryRequest(BaseModel):
    subject: str
    body: str
    max_words: int = 50

@router.post("/summarize-email")
async def summarize_email(request: EmailSummaryRequest):
    """
    Summarize an email using Claude
    """
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="ANTHROPIC_API_KEY not set")

    client = Anthropic(api_key=api_key)

    prompt = f"""Summarize this email in {request.max_words} words or less:

Subject: {request.subject}

{request.body}

Provide a concise summary that captures the main points and any action items."""

    message = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=200,
        messages=[{"role": "user", "content": prompt}]
    )

    return {
        "summary": message.content[0].text,
        "original_subject": request.subject,
        "tokens_used": message.usage.input_tokens + message.usage.output_tokens
    }
```

### n8n Workflow

1. **Gmail Trigger** - On new email
   - Label: Inbox
   - Filter: Has attachment or length > 1000 chars

2. **HTTP Request** - Python summarization
   - Method: POST
   - URL: `http://python-runtime:8000/llm/summarize-email`
   - Body:
   ```json
   {
     "subject": "{{ $json.subject }}",
     "body": "{{ $json.textPlain }}",
     "max_words": 50
   }
   ```

3. **Gmail** - Apply label
   - Label: "AI/Summarized"

4. **Slack** - Send notification
   ```
   📧 New Email Summary
   From: {{ $('Gmail Trigger').item.json.from }}
   Subject: {{ $('Gmail Trigger').item.json.subject }}

   Summary: {{ $json.summary }}
   ```

---

## Recipe 2: Smart Web Scraper with Data Extraction

**Use case:** Scrape websites and extract structured data

### Python Code

**Add to requirements.txt:**
```
beautifulsoup4
playwright
```

**Create `python/app/routers/scraper.py`:**

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx
from bs4 import BeautifulSoup
from typing import Optional, List, Dict

router = APIRouter(prefix="/scraper", tags=["scraper"])

class ScrapeRequest(BaseModel):
    url: str
    selector: Optional[str] = None
    extract_type: str = "text"  # "text", "links", "images", "table"

@router.post("/scrape")
async def scrape_website(request: ScrapeRequest):
    """
    Scrape a website and extract data based on type
    """
    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(
                request.url,
                headers={"User-Agent": "Mozilla/5.0"}
            )
            response.raise_for_status()

        soup = BeautifulSoup(response.text, 'html.parser')
        result = {}

        if request.extract_type == "text":
            if request.selector:
                elements = soup.select(request.selector)
                result["data"] = [el.get_text(strip=True) for el in elements]
            else:
                result["data"] = soup.get_text(strip=True)

        elif request.extract_type == "links":
            links = []
            for link in soup.find_all('a', href=True):
                links.append({
                    "text": link.get_text(strip=True),
                    "url": link['href']
                })
            result["data"] = links

        elif request.extract_type == "images":
            images = []
            for img in soup.find_all('img', src=True):
                images.append({
                    "alt": img.get('alt', ''),
                    "src": img['src']
                })
            result["data"] = images

        elif request.extract_type == "table":
            tables = []
            for table in soup.find_all('table'):
                rows = []
                for row in table.find_all('tr'):
                    cells = [cell.get_text(strip=True) for cell in row.find_all(['td', 'th'])]
                    rows.append(cells)
                tables.append(rows)
            result["data"] = tables

        return {
            "url": request.url,
            "extract_type": request.extract_type,
            "result": result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Include router in `main.py`:**
```python
from app.routers import llm, scraper

app.include_router(llm.router)
app.include_router(scraper.router)
```

### n8n Workflow: Daily Product Price Monitor

1. **Schedule Trigger** - Daily at 6 AM

2. **Set** - URLs to monitor
   ```json
   {
     "products": [
       {"name": "Item 1", "url": "https://example.com/product1", "selector": ".price"},
       {"name": "Item 2", "url": "https://example.com/product2", "selector": ".price"}
     ]
   }
   ```

3. **Split In Batches** - One product at a time

4. **HTTP Request** - Python scraper
   - URL: `http://python-runtime:8000/scraper/scrape`
   - Body:
   ```json
   {
     "url": "{{ $json.url }}",
     "selector": "{{ $json.selector }}",
     "extract_type": "text"
   }
   ```

5. **Function** - Parse price
   ```javascript
   const priceText = $json.result.data[0];
   const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));

   return {
     product: $('Split In Batches').item.json.name,
     price: price,
     previous_price: $context.previousPrices?.[product] || null,
     changed: price !== $context.previousPrices?.[product]
   };
   ```

6. **IF** - Price decreased?

7. **Slack** - Send alert
   ```
   🔔 Price Drop Alert!
   {{ $json.product }}: ${{ $json.price }}
   Was: ${{ $json.previous_price }}
   ```

---

## Recipe 3: Document Analysis Pipeline

**Use case:** Process uploaded documents with AI

### Python Code

**Add to requirements.txt:**
```
pypdf2
python-docx
pillow
pytesseract
```

**Create `python/app/routers/documents.py`:**

```python
from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
import PyPDF2
import docx
from PIL import Image
import pytesseract
from pathlib import Path
from anthropic import Anthropic
import os

router = APIRouter(prefix="/documents", tags=["documents"])

@router.post("/extract-text")
async def extract_text(file: UploadFile = File(...)):
    """
    Extract text from various document types
    """
    content = await file.read()
    text = ""

    try:
        if file.filename.endswith('.pdf'):
            from io import BytesIO
            pdf_reader = PyPDF2.PdfReader(BytesIO(content))
            for page in pdf_reader.pages:
                text += page.extract_text() + "\n"

        elif file.filename.endswith('.docx'):
            from io import BytesIO
            doc = docx.Document(BytesIO(content))
            for para in doc.paragraphs:
                text += para.text + "\n"

        elif file.filename.endswith(('.png', '.jpg', '.jpeg')):
            from io import BytesIO
            image = Image.open(BytesIO(content))
            text = pytesseract.image_to_string(image)

        else:
            raise HTTPException(status_code=400, detail="Unsupported file type")

        return {
            "filename": file.filename,
            "text": text.strip(),
            "word_count": len(text.split())
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


class AnalyzeDocumentRequest(BaseModel):
    text: str
    analysis_type: str  # "summary", "topics", "sentiment", "questions"

@router.post("/analyze")
async def analyze_document(request: AnalyzeDocumentRequest):
    """
    Analyze document text using Claude
    """
    api_key = os.getenv("ANTHROPIC_API_KEY")
    client = Anthropic(api_key=api_key)

    prompts = {
        "summary": f"Summarize this document in 3-5 bullet points:\n\n{request.text}",
        "topics": f"Extract the main topics discussed in this document:\n\n{request.text}",
        "sentiment": f"Analyze the sentiment and tone of this document:\n\n{request.text}",
        "questions": f"Generate 5 key questions answered by this document:\n\n{request.text}"
    }

    prompt = prompts.get(request.analysis_type, prompts["summary"])

    message = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )

    return {
        "analysis_type": request.analysis_type,
        "result": message.content[0].text
    }
```

### n8n Workflow: Document Processing

1. **Webhook** - Receive file upload
   - Binary Data: true

2. **HTTP Request** - Extract text
   - Method: POST
   - URL: `http://python-runtime:8000/documents/extract-text`
   - Body: Binary file from webhook

3. **HTTP Request** - Analyze (summary)
   - Method: POST
   - URL: `http://python-runtime:8000/documents/analyze`
   - Body:
   ```json
   {
     "text": "{{ $json.text }}",
     "analysis_type": "summary"
   }
   ```

4. **HTTP Request** - Analyze (topics)
   - URL: `http://python-runtime:8000/documents/analyze`
   - Body:
   ```json
   {
     "text": "{{ $('HTTP Request').item.json.text }}",
     "analysis_type": "topics"
   }
   ```

5. **Notion** - Create page with analysis
   - Title: Original filename
   - Content: Summary + Topics

6. **Email** - Send confirmation

---

## Recipe 4: Multi-Channel Notification System

**Use case:** Send notifications to multiple platforms based on priority

### Python Code

**Create `python/app/routers/notifications.py`:**

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import httpx
import os

router = APIRouter(prefix="/notifications", tags=["notifications"])

class Notification(BaseModel):
    title: str
    message: str
    priority: str  # "low", "medium", "high", "critical"
    channels: List[str]  # ["slack", "discord", "email", "telegram"]
    metadata: Optional[dict] = {}


@router.post("/send")
async def send_notification(notification: Notification):
    """
    Send notification to multiple channels based on priority
    """
    results = []

    # Determine which channels to use based on priority
    if notification.priority == "critical":
        channels = ["slack", "discord", "email", "telegram"]
    elif notification.priority == "high":
        channels = ["slack", "email"]
    elif notification.priority == "medium":
        channels = ["slack"]
    else:
        channels = []

    # Override with explicitly requested channels
    if notification.channels:
        channels = notification.channels

    # Send to each channel
    async with httpx.AsyncClient() as client:

        if "slack" in channels:
            slack_webhook = os.getenv("SLACK_WEBHOOK_URL")
            if slack_webhook:
                response = await client.post(slack_webhook, json={
                    "text": f"*{notification.title}*\n{notification.message}"
                })
                results.append({"channel": "slack", "status": response.status_code})

        if "discord" in channels:
            discord_webhook = os.getenv("DISCORD_WEBHOOK_URL")
            if discord_webhook:
                response = await client.post(discord_webhook, json={
                    "content": f"**{notification.title}**\n{notification.message}"
                })
                results.append({"channel": "discord", "status": response.status_code})

    return {
        "notification_id": notification.metadata.get("id", "unknown"),
        "priority": notification.priority,
        "channels_notified": results,
        "success": all(r["status"] < 300 for r in results)
    }
```

### n8n Workflow: Intelligent Alert Router

1. **Webhook** - Receive alert

2. **Function** - Classify priority
   ```javascript
   const keywords_critical = ['down', 'failed', 'critical', 'urgent'];
   const keywords_high = ['error', 'warning', 'issue'];

   const text = ($json.message || '').toLowerCase();

   let priority = 'low';
   if (keywords_critical.some(k => text.includes(k))) {
     priority = 'critical';
   } else if (keywords_high.some(k => text.includes(k))) {
     priority = 'high';
   } else if ($json.source === 'production') {
     priority = 'medium';
   }

   return {
     ...$json,
     priority
   };
   ```

3. **HTTP Request** - Python notification service
   - URL: `http://python-runtime:8000/notifications/send`
   - Body:
   ```json
   {
     "title": "{{ $json.title }}",
     "message": "{{ $json.message }}",
     "priority": "{{ $json.priority }}",
     "channels": [],
     "metadata": {"id": "{{ $json.id }}", "source": "{{ $json.source }}"}
   }
   ```

4. **Database** - Log notification
   - Table: notifications
   - Columns: timestamp, priority, message, channels, success

---

## Recipe 5: Smart Content Calendar

**Use case:** Generate social media posts with AI and schedule them

### Python Code

**Add to `python/app/routers/llm.py`:**

```python
@router.post("/generate-post")
async def generate_social_post(
    topic: str,
    platform: str,  # "twitter", "linkedin", "instagram"
    tone: str = "professional"
):
    """
    Generate platform-specific social media post
    """
    api_key = os.getenv("ANTHROPIC_API_KEY")
    client = Anthropic(api_key=api_key)

    limits = {
        "twitter": "280 characters",
        "linkedin": "1300 characters, professional tone",
        "instagram": "2200 characters, include emoji"
    }

    prompt = f"""Generate a {tone} social media post for {platform} about: {topic}

Requirements:
- Platform: {platform}
- Limits: {limits.get(platform, "500 characters")}
- Tone: {tone}
- Include relevant hashtags
- Make it engaging and actionable

Just provide the post text, no explanations."""

    message = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}]
    )

    return {
        "topic": topic,
        "platform": platform,
        "post": message.content[0].text,
        "character_count": len(message.content[0].text)
    }
```

### n8n Workflow: Weekly Content Generation

1. **Schedule Trigger** - Monday 9 AM

2. **Set** - Content topics
   ```json
   {
     "topics": [
       "AI automation tips",
       "Productivity hacks",
       "Tech trends 2026"
     ],
     "platforms": ["twitter", "linkedin"]
   }
   ```

3. **Split In Batches** - Process topics

4. **Loop Over Items** (platforms)

5. **HTTP Request** - Generate post
   - URL: `http://python-runtime:8000/llm/generate-post`
   - Body:
   ```json
   {
     "topic": "{{ $json.topic }}",
     "platform": "{{ $json.platform }}",
     "tone": "professional"
   }
   ```

6. **Google Sheets** - Add to content calendar
   - Columns: Date, Platform, Topic, Post, Status

7. **Notion** - Create draft post
   - Database: Content Calendar
   - Status: Draft
   - Scheduled Date: Next available slot

8. **Slack** - Notify team
   ```
   📅 New content draft ready for review
   Topic: {{ $json.topic }}
   Platform: {{ $json.platform }}
   Preview: {{ $json.post.substring(0, 100) }}...
   ```

---

## Recipe 6: API Health Monitor with Anomaly Detection

**Use case:** Monitor APIs and detect unusual patterns

### Python Code

**Create `python/app/routers/monitoring.py`:**

```python
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict
import httpx
from datetime import datetime
import statistics

router = APIRouter(prefix="/monitoring", tags=["monitoring"])

class HealthCheck(BaseModel):
    endpoints: List[str]

@router.post("/check-health")
async def check_health(request: HealthCheck):
    """
    Check health of multiple endpoints
    """
    results = []

    async with httpx.AsyncClient(timeout=10.0) as client:
        for url in request.endpoints:
            try:
                start = datetime.now()
                response = await client.get(url)
                duration = (datetime.now() - start).total_seconds()

                results.append({
                    "url": url,
                    "status": response.status_code,
                    "duration_seconds": duration,
                    "healthy": response.status_code < 400 and duration < 5.0,
                    "timestamp": datetime.now().isoformat()
                })
            except Exception as e:
                results.append({
                    "url": url,
                    "status": 0,
                    "duration_seconds": None,
                    "healthy": False,
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                })

    return {
        "checked_count": len(request.endpoints),
        "healthy_count": sum(1 for r in results if r["healthy"]),
        "results": results
    }


class AnomalyDetectionRequest(BaseModel):
    metric_history: List[float]  # Historical values
    current_value: float
    threshold_std: float = 2.0  # Standard deviations

@router.post("/detect-anomaly")
async def detect_anomaly(request: AnomalyDetectionRequest):
    """
    Detect if current value is anomalous compared to history
    """
    if len(request.metric_history) < 3:
        return {"anomaly": False, "reason": "Insufficient historical data"}

    mean = statistics.mean(request.metric_history)
    std_dev = statistics.stdev(request.metric_history)

    z_score = (request.current_value - mean) / std_dev if std_dev > 0 else 0
    is_anomaly = abs(z_score) > request.threshold_std

    return {
        "current_value": request.current_value,
        "historical_mean": mean,
        "historical_std": std_dev,
        "z_score": z_score,
        "anomaly": is_anomaly,
        "severity": "high" if abs(z_score) > 3 else "medium" if abs(z_score) > 2 else "low"
    }
```

### n8n Workflow: Continuous Monitoring

1. **Schedule Trigger** - Every 5 minutes

2. **HTTP Request** - Check endpoints
   - URL: `http://python-runtime:8000/monitoring/check-health`
   - Body:
   ```json
   {
     "endpoints": [
       "https://api.example.com/health",
       "https://app.example.com/status"
     ]
   }
   ```

3. **Split In Batches** - Process each result

4. **IF** - Endpoint unhealthy?

5. **HTTP Request** - Get historical data
   - Fetch last 20 response times from database

6. **HTTP Request** - Detect anomaly
   - URL: `http://python-runtime:8000/monitoring/detect-anomaly`
   - Body:
   ```json
   {
     "metric_history": "{{ $json.history }}",
     "current_value": "{{ $json.duration_seconds }}"
   }
   ```

7. **IF** - Anomaly detected?

8. **Send Alert** - Via notification service
   ```
   ⚠️ Anomaly Detected
   Endpoint: {{ $json.url }}
   Current: {{ $json.current_value }}s
   Expected: {{ $json.historical_mean }}s
   Severity: {{ $json.severity }}
   ```

---

## Quick Start Template

Here's a minimal example to test your setup:

### Python (`main.py`)

```python
from fastapi import FastAPI

app = FastAPI(title="Automation Python Runtime")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/hello")
async def hello(name: str):
    return {"message": f"Hello, {name}!"}
```

### n8n Workflow

1. **Manual Trigger**
   ```json
   {"name": "World"}
   ```

2. **HTTP Request**
   - Method: POST
   - URL: `http://python-runtime:8000/hello`
   - Query Parameters: `name={{ $json.name }}`

3. **Sticky Note**
   ```
   Result: {{ $json.message }}
   ```

Should return: `{"message": "Hello, World!"}`

---

## Deployment Checklist

Before using these recipes in production:

- [ ] Add API keys to `compose/.env`
- [ ] Update `python/requirements.txt` with needed dependencies
- [ ] Rebuild Python container: `podman-compose up -d --build python-runtime`
- [ ] Test endpoints with curl first
- [ ] Set up error handling in n8n workflows
- [ ] Enable backup timers
- [ ] Configure notification channels
- [ ] Test end-to-end workflows
- [ ] Document custom endpoints

---

For more patterns, see `n8n-workflow-patterns.md` and `python-runtime-guide.md`.
