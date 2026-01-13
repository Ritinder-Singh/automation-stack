# n8n Workflow Patterns Guide

Common workflow patterns and best practices for integrating n8n with the Python runtime.

---

## Core Concepts

**n8n's Role:**
- Orchestration and scheduling
- Visual workflow management
- Triggers (webhooks, schedules, manual)
- Light data transformation
- Calling external services

**Python's Role:**
- Heavy computation
- LLM API calls
- Complex data processing
- Long-running tasks
- Business logic

**Rule of Thumb:**
- Use n8n for: Connecting services, scheduling, branching logic, light transforms
- Use Python for: Heavy processing, AI/LLM, complex algorithms, external API wrappers

---

## Pattern 1: Simple Request-Response

**Use case:** Quick data processing or transformation

```
[Trigger] → [HTTP Request to Python] → [Use Result] → [Action]
```

### Example: Text Analysis

**Workflow Nodes:**

1. **Manual Trigger** (or Schedule/Webhook)

2. **Set** Node - Prepare data
   ```json
   {
     "text": "This is a sample text to analyze",
     "action": "sentiment"
   }
   ```

3. **HTTP Request** Node
   - Method: POST
   - URL: `http://python-runtime:8000/analyze`
   - Body: JSON
   ```json
   {
     "text": "{{ $json.text }}",
     "action": "{{ $json.action }}"
   }
   ```

4. **IF** Node - Branch based on result
   - Condition: `{{ $json.sentiment }}` equals "positive"

5a. **Slack** - Send positive notification

5b. **Discord** - Send negative alert

---

## Pattern 2: Batch Processing

**Use case:** Process arrays of items through Python

```
[Trigger] → [Get Data] → [Split In Batches] → [Python Process] → [Aggregate]
```

### Example: Enrich User Data with LLM

**Workflow:**

1. **Schedule Trigger** - Every Monday at 9 AM

2. **HTTP Request** - Fetch users from API
   ```
   GET https://api.example.com/users
   ```

3. **Split In Batches**
   - Batch Size: 10
   - Options: Reset after each batch

4. **HTTP Request to Python**
   - URL: `http://python-runtime:8000/llm/enrich-profile`
   - Body:
   ```json
   {
     "user_id": "{{ $json.id }}",
     "bio": "{{ $json.bio }}"
   }
   ```

5. **HTTP Request** - Update user in database
   ```json
   {
     "user_id": "{{ $json.user_id }}",
     "enriched_data": "{{ $json.result }}"
   }
   ```

6. **Aggregate** - Collect all results

7. **Send Summary Email**

---

## Pattern 3: Async Long-Running Tasks

**Use case:** Operations that take > 30 seconds

```
[Trigger] → [Start Python Task] → [Wait/Poll] → [Process Result]
```

Or with webhooks:

```
[Webhook Trigger] ← [Python Callback] ← [Python Processing]
                                              ↑
[HTTP Request] → [Start Task] → [Return task_id]
```

### Example: Generate Video with AI

**Workflow 1: Start Task**

1. **Webhook** Node
   - Copy webhook URL (e.g., `http://192.168.1.9:5678/webhook/video-complete`)

2. **HTTP Request** - Start video generation
   - URL: `http://python-runtime:8000/video/generate`
   - Body:
   ```json
   {
     "prompt": "{{ $json.prompt }}",
     "callback_url": "http://n8n:5678/webhook/video-complete"
   }
   ```
   Response: `{"task_id": "abc123", "status": "started"}`

3. **Response** Node - Return to caller
   ```json
   {
     "task_id": "{{ $json.task_id }}",
     "message": "Processing started"
   }
   ```

**Workflow 2: Handle Completion (Webhook)**

1. **Webhook** Trigger
   - Path: `/webhook/video-complete`

2. **IF** Node - Check status
   - Condition: `{{ $json.status }}` equals "completed"

3. **HTTP Request** - Download video from Python
   - URL: `http://python-runtime:8000/video/download/{{ $json.task_id }}`

4. **Upload to Cloud Storage**

5. **Send Notification** - Email with link

---

## Pattern 4: Error Handling & Retry

**Use case:** Resilient workflows that handle failures gracefully

```
[Trigger] → [Try Python] → [On Error] → [Retry or Alert]
```

### Example: Resilient API Call

**Workflow:**

1. **Webhook** Trigger

2. **HTTP Request** to Python
   - URL: `http://python-runtime:8000/external/api-call`
   - Continue On Fail: ✓ (Enable)

3. **IF** Node - Check for errors
   - Condition: `{{ $json.error }}` is empty

**True branch (Success):**

4a. **Process Result**

5a. **Return Success**

**False branch (Error):**

4b. **Function** Node - Log error
   ```javascript
   return {
     error: $json.error,
     timestamp: new Date().toISOString(),
     attempt: $json.attempt || 1
   }
   ```

5b. **IF** Node - Check retry count
   - Condition: `{{ $json.attempt }}` less than 3

**Retry:**

6b1. **Wait** - 5 seconds

6b2. **Loop back** to step 2 (use Execute Workflow node)

**Give up:**

6b3. **Send Alert** - Notify admin

6b4. **Return Error Response**

---

## Pattern 5: Parallel Execution

**Use case:** Multiple independent operations

```
        ┌→ [Python Task 1] →┐
[Trigger] ┤                   ├→ [Combine] → [Next]
        └→ [Python Task 2] →┘
```

### Example: Multi-Model LLM Comparison

**Workflow:**

1. **Manual Trigger**
   ```json
   {
     "prompt": "Explain quantum computing in simple terms"
   }
   ```

2. **Split Out** Node - Duplicate data to 3 branches

**Branch 1: Claude**

3a. **HTTP Request**
   - URL: `http://python-runtime:8000/llm/claude`
   - Body: `{"prompt": "{{ $json.prompt }}"}`

**Branch 2: GPT-4**

3b. **HTTP Request**
   - URL: `http://python-runtime:8000/llm/gpt4`
   - Body: `{"prompt": "{{ $json.prompt }}"}`

**Branch 3: Local Model**

3c. **HTTP Request**
   - URL: `http://python-runtime:8000/llm/local`
   - Body: `{"prompt": "{{ $json.prompt }}"}`

**Merge:**

4. **Merge** Node - Combine all responses

5. **Code** Node - Compare responses
   ```javascript
   const responses = $input.all();
   return {
     prompt: responses[0].json.prompt,
     models: responses.map(r => ({
       model: r.json.model,
       response: r.json.response,
       tokens: r.json.usage
     })),
     best: selectBest(responses) // Custom logic
   }
   ```

6. **Notion** - Save comparison to database

---

## Pattern 6: Human-in-the-Loop

**Use case:** Require human approval before proceeding

```
[Trigger] → [Process] → [Send for Approval] → [Wait] → [On Approve] → [Execute]
```

### Example: Content Moderation

**Workflow:**

1. **Webhook** - Receive content submission

2. **HTTP Request to Python**
   - URL: `http://python-runtime:8000/llm/moderate`
   - Body: `{"content": "{{ $json.content }}"}`

3. **IF** Node - Check moderation score
   - Condition: `{{ $json.score }}` greater than 0.8

**Auto-approve:**

4a. **Publish Content**

**Needs review:**

4b. **Send Email** - To moderator with approve/reject links
   - Approve link: `http://192.168.1.9:5678/webhook/approve/{{ $json.id }}`
   - Reject link: `http://192.168.1.9:5678/webhook/reject/{{ $json.id }}`

**Separate Workflows for Approve/Reject:**

**Approve Workflow:**
1. Webhook Trigger: `/webhook/approve/:id`
2. Publish Content
3. Notify Submitter

**Reject Workflow:**
1. Webhook Trigger: `/webhook/reject/:id`
2. Notify Submitter with Reason

---

## Pattern 7: Scheduled Aggregation

**Use case:** Periodic data collection and reporting

```
[Schedule] → [Collect Data] → [Python Analysis] → [Generate Report] → [Distribute]
```

### Example: Daily Analytics Report

**Workflow:**

1. **Schedule Trigger**
   - Cron: `0 8 * * *` (8 AM daily)

2. **HTTP Request** - Fetch yesterday's data
   - URL: `https://api.analytics.com/data`
   - Query: `date={{ $now.minus(1, 'day').toFormat('yyyy-MM-dd') }}`

3. **HTTP Request to Python**
   - URL: `http://python-runtime:8000/data/analyze`
   - Body: `{"data": "{{ $json.events }}", "type": "daily"}`

4. **HTTP Request to Python**
   - URL: `http://python-runtime:8000/llm/summarize`
   - Body: `{"data": "{{ $json.analysis }}", "format": "executive_summary"}`

5. **Google Sheets** - Log raw data

6. **Gmail** - Send report
   - To: team@example.com
   - Subject: `Daily Analytics - {{ $now.toFormat('yyyy-MM-dd') }}`
   - Body: HTML template with `{{ $json.summary }}`

---

## Pattern 8: Event-Driven Automation

**Use case:** React to external events in real-time

```
[External Webhook] → [Validate] → [Python Process] → [Take Action]
```

### Example: GitHub PR Review with AI

**Workflow:**

1. **Webhook** Trigger
   - Path: `/webhook/github-pr`
   - Expected: GitHub PR webhook payload

2. **IF** Node - Filter event type
   - Condition: `{{ $json.action }}` equals "opened"

3. **HTTP Request** - Fetch PR diff
   - URL: `{{ $json.pull_request.diff_url }}`
   - Headers: `Authorization: token {{ $env.GITHUB_TOKEN }}`

4. **HTTP Request to Python**
   - URL: `http://python-runtime:8000/llm/code-review`
   - Body:
   ```json
   {
     "diff": "{{ $json.data }}",
     "language": "{{ $json.pull_request.base.repo.language }}"
   }
   ```

5. **IF** Node - Check for issues
   - Condition: `{{ $json.issues.length }}` greater than 0

**Issues found:**

6a. **HTTP Request** - Post review comment to GitHub
   - URL: `{{ $json.pull_request.comments_url }}`
   - Method: POST
   - Body:
   ```json
   {
     "body": "🤖 AI Code Review:\n\n{{ $json.review }}"
   }
   ```

**No issues:**

6b. **HTTP Request** - Add approval label

---

## Best Practices

### 1. Error Handling

Always enable "Continue On Fail" for external HTTP requests and handle errors explicitly:

```
[HTTP Request] (Continue On Fail: ✓)
    ↓
[IF Node: Check $json.error exists]
    ↓ (true)
[Error Handler]
```

### 2. Data Validation

Validate data before sending to Python:

```javascript
// In Function/Code node
if (!$json.email || !$json.email.includes('@')) {
  throw new Error('Invalid email');
}
return $json;
```

### 3. Idempotency

For important operations, use idempotency keys:

```json
{
  "data": "{{ $json.data }}",
  "idempotency_key": "{{ $json.id }}_{{ $now.toMillis() }}"
}
```

### 4. Logging

Add **Sticky Note** nodes to document workflow logic and **Function** nodes to log:

```javascript
console.log('Processing item:', $json.id);
return $json;
```

### 5. Reusable Sub-Workflows

Create sub-workflows for common operations:
- Error notification
- Data transformation
- API authentication

Use **Execute Workflow** node to call them.

### 6. Use Environment Variables

Store sensitive data in n8n's Credentials system, not in workflow data:
- API keys
- Database credentials
- Webhook URLs

### 7. Rate Limiting

For external APIs, use **Wait** nodes between batch items:

```
[Split In Batches]
    ↓
[Python Process]
    ↓
[Wait: 1 second]  ← Prevents rate limit
    ↓
[Loop back]
```

---

## Debugging Tips

### 1. Use Manual Trigger During Development

Test workflows step-by-step before scheduling.

### 2. Enable "Continue On Fail"

Prevent workflow from stopping on errors during testing.

### 3. Check Execution History

n8n UI → Executions tab shows all workflow runs with input/output data.

### 4. Inspect Python Logs

```bash
podman logs -f python-runtime
```

### 5. Use Function Node for Debugging

```javascript
console.log('Current data:', JSON.stringify($json, null, 2));
return $json;
```

### 6. Test Python Endpoints Separately

Use curl to isolate issues:
```bash
curl -X POST http://127.0.0.1:8000/your-endpoint \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

---

## Example Starter Workflows

### 1. Daily News Digest with AI Summary

1. Schedule (daily)
2. RSS Feed (news sources)
3. Split In Batches
4. Python → LLM summarize each article
5. Aggregate summaries
6. Send email digest

### 2. Slack Command Bot

1. Webhook (from Slack slash command)
2. Parse command and parameters
3. Python → Process command (LLM, data lookup, etc.)
4. Format response
5. Return to Slack

### 3. Content Pipeline

1. Webhook (content submission)
2. Python → AI moderation check
3. IF approved → Publish
4. IF rejected → Send notification
5. Log to database

### 4. API Health Monitor

1. Schedule (every 5 minutes)
2. HTTP Request (check endpoint)
3. IF error → Python log analysis
4. IF critical → Send alert
5. Log to metrics database

### 5. Smart Email Responder

1. Gmail Trigger (new email)
2. Python → LLM classify email
3. IF support request → Python generate draft response
4. IF urgent → Alert team
5. ELSE → File in appropriate folder

---

## Next Steps

1. Build your first workflow using Pattern 1 (Simple Request-Response)
2. Test Python integration end-to-end
3. Explore n8n's built-in nodes (Gmail, Slack, Sheets, etc.)
4. Create reusable sub-workflows for common operations
5. Set up proper error handling and monitoring

---

Happy automating! 🚀
