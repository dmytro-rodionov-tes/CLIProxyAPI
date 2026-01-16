# API Usage Guide

CLIProxyAPI provides OpenAI-compatible endpoints. Use your configured `API_KEY` for authentication.

## Quick Test

```bash
# Set your variables
export BASE_URL="https://your-domain.com"
export API_KEY="your-api-key"

# Test connection
curl $BASE_URL/

# List available models
curl $BASE_URL/v1/models -H "Authorization: Bearer $API_KEY"
```

---

## Endpoints

### GET /v1/models

List all available models from your authenticated providers.

```bash
curl $BASE_URL/v1/models \
  -H "Authorization: Bearer $API_KEY"
```

**Response:**
```json
{
  "object": "list",
  "data": [
    {"id": "claude-sonnet-4-20250514", "object": "model", "owned_by": "anthropic"},
    {"id": "gpt-4o", "object": "model", "owned_by": "openai"},
    {"id": "gemini-2.5-pro", "object": "model", "owned_by": "google"}
  ]
}
```

---

### POST /v1/chat/completions

Send chat messages (OpenAI-compatible format).

**Basic request:**
```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'
```

**With streaming:**
```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
      {"role": "user", "content": "Write a haiku about coding"}
    ],
    "stream": true
  }'
```

**With system prompt:**
```bash
curl $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
      {"role": "system", "content": "You are a helpful coding assistant."},
      {"role": "user", "content": "How do I reverse a string in Python?"}
    ]
  }'
```

**Response:**
```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "claude-sonnet-4-20250514",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! I'm doing well, thank you for asking."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 15,
    "total_tokens": 25
  }
}
```

---

### POST /v1/completions

Legacy completions endpoint (non-chat format).

```bash
curl $BASE_URL/v1/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "prompt": "The quick brown fox",
    "max_tokens": 50
  }'
```

---

### POST /v1/messages

Claude-native messages API (for Claude Code compatibility).

```bash
curl $BASE_URL/v1/messages \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Hello, Claude!"}
    ]
  }'
```

---

## Using with Tools

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://your-domain.com/v1",
    api_key="your-api-key"
)

response = client.chat.completions.create(
    model="claude-sonnet-4-20250514",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)
```

### Python (Anthropic SDK)

```python
import anthropic

client = anthropic.Anthropic(
    base_url="https://your-domain.com",
    api_key="your-api-key"
)

message = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(message.content[0].text)
```

### Node.js

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'https://your-domain.com/v1',
  apiKey: 'your-api-key',
});

const response = await client.chat.completions.create({
  model: 'claude-sonnet-4-20250514',
  messages: [{ role: 'user', content: 'Hello!' }],
});

console.log(response.choices[0].message.content);
```

### cURL with jq (pretty output)

```bash
curl -s $BASE_URL/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Hello!"}]
  }' | jq '.choices[0].message.content'
```

---

## Using with AI Coding Tools

### Claude Code

```bash
export ANTHROPIC_BASE_URL="https://your-domain.com"
export ANTHROPIC_API_KEY="your-api-key"
claude
```

### Cursor

Settings → Models → OpenAI API Key:
- API Key: `your-api-key`
- Base URL: `https://your-domain.com/v1`

### Continue (VS Code)

In `~/.continue/config.json`:
```json
{
  "models": [
    {
      "title": "Claude via Proxy",
      "provider": "openai",
      "model": "claude-sonnet-4-20250514",
      "apiBase": "https://your-domain.com/v1",
      "apiKey": "your-api-key"
    }
  ]
}
```

### Cline / Roo Code

Set in extension settings:
- API Provider: OpenAI Compatible
- Base URL: `https://your-domain.com/v1`
- API Key: `your-api-key`

### aider

```bash
export OPENAI_API_BASE="https://your-domain.com/v1"
export OPENAI_API_KEY="your-api-key"
aider --model claude-sonnet-4-20250514
```

---

## Model Routing

### Available Models

Models depend on your authenticated providers. Common examples:

| Provider | Models |
|----------|--------|
| Claude | `claude-sonnet-4-20250514`, `claude-opus-4-20250514` |
| Codex/OpenAI | `gpt-4o`, `gpt-4o-mini`, `o1`, `o3-mini` |
| Gemini | `gemini-2.5-pro`, `gemini-2.5-flash` |
| Copilot | `gpt-4o`, `claude-sonnet-4-20250514` (via Copilot) |

### Force Provider Routing

Prefix model name to force a specific provider:

```bash
# Force Copilot provider
"model": "copilot-gpt-4o"

# Force Claude provider
"model": "claude-claude-sonnet-4-20250514"
```

---

## Management API

Access the web UI at: `https://your-domain.com/management.html`

Or use the API directly:

```bash
# Get usage statistics
curl $BASE_URL/v0/management/usage \
  -H "Authorization: Bearer $MANAGEMENT_PASSWORD"

# Get current config
curl $BASE_URL/v0/management/config \
  -H "Authorization: Bearer $MANAGEMENT_PASSWORD"

# List auth files
curl $BASE_URL/v0/management/auth-files \
  -H "Authorization: Bearer $MANAGEMENT_PASSWORD"
```

---

## Error Handling

### Common Errors

**401 Unauthorized:**
```json
{"error": "Missing API key"}
```
→ Add `Authorization: Bearer your-api-key` header

**404 Model Not Found:**
```json
{"error": "Model not found"}
```
→ Check available models with `GET /v1/models`

**429 Rate Limited:**
```json
{"error": "Rate limit exceeded"}
```
→ Provider quota exceeded, wait or add more credentials

**503 Service Unavailable:**
```json
{"error": "No available credentials"}
```
→ All credentials exhausted or in cooldown

---

## Tips

1. **Check models first** - Run `GET /v1/models` to see what's available
2. **Use streaming** - Set `"stream": true` for long responses
3. **Monitor usage** - Check `/management.html` for quota status
4. **Multiple credentials** - Add multiple auth files for load balancing
5. **Routing strategy** - Configure `round-robin` or `fill-first` in config
