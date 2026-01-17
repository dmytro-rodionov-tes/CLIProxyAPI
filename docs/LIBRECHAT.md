# LibreChat Integration

LibreChat is a full-featured AI chat interface that works with CLIProxyAPI to provide a ChatGPT-like experience with all your AI providers.

## Quick Start

### 1. Configure LibreChat

Copy the example configuration:

```bash
cp librechat/librechat.yaml.example librechat/librechat.yaml
```

Edit `librechat/librechat.yaml` if you want to customize:
- Available models
- Model display names
- Rate limits

### 2. Start the Stack

```bash
# Start CLIProxyAPI + LibreChat
docker compose -f docker-compose.yml -f docker-compose.librechat.yml up -d
```

This starts:
- **CLIProxyAPI** on port 8317 (API proxy)
- **LibreChat** on port 3080 (Chat UI)
- **MongoDB** (LibreChat database)
- **Meilisearch** (Conversation search)

### 3. Access LibreChat

Open http://localhost:3080 in your browser.

1. Create an account (registration is enabled by default)
2. Select "CLIProxyAPI" as your AI provider
3. Start chatting with any model available through your proxy

## Architecture

```
Browser --> LibreChat (port 3080)
                |
                v
         CLI Proxy API (port 8317)
                |
    +-----------+-----------+
    |           |           |
 Claude     Gemini     Copilot
```

## Configuration

### Environment Variables

Set these in your `.env` file or docker-compose environment:

| Variable | Description | Default |
|----------|-------------|---------|
| `API_KEY` | CLIProxyAPI key (shared with LibreChat) | *required* |
| `LIBRECHAT_PORT` | LibreChat web port | `3080` |
| `LIBRECHAT_ALLOW_REGISTRATION` | Allow new user signups | `true` |
| `MEILI_MASTER_KEY` | Meilisearch API key | `masterKey` |

### Security Keys

For production, generate secure keys:

```bash
# Generate encryption keys
echo "LIBRECHAT_CREDS_KEY=$(openssl rand -hex 32)"
echo "LIBRECHAT_CREDS_IV=$(openssl rand -hex 16)"
echo "LIBRECHAT_JWT_SECRET=$(openssl rand -hex 32)"
echo "LIBRECHAT_JWT_REFRESH_SECRET=$(openssl rand -hex 32)"
```

Add these to your `.env` file.

### LibreChat Configuration

The `librechat/librechat.yaml` file configures:

- **Endpoints**: Which AI backends are available
- **Models**: Available models and their settings
- **ModelSpecs**: UI labels, descriptions, context windows

Example custom endpoint:

```yaml
endpoints:
  custom:
    - name: "CLIProxyAPI"
      apiKey: "${API_KEY}"
      baseURL: "http://cli-proxy-api:8317/v1"
      models:
        default:
          - claude-sonnet-4-20250514
          - gemini-2.5-pro
        fetch: true  # Auto-discover available models
```

## Available Models

LibreChat shows all models available through CLIProxyAPI:

| Provider | Models |
|----------|--------|
| Claude | claude-sonnet-4, claude-opus-4, claude-3.5-sonnet, claude-3.5-haiku |
| Gemini | gemini-2.5-flash, gemini-2.5-pro |
| OpenAI/Codex | gpt-4o, gpt-4o-mini, o1, o1-mini |
| Copilot | (depends on authentication) |

Models are auto-discovered from CLIProxyAPI when `fetch: true` is set.

## Troubleshooting

### LibreChat shows "No models available"

1. Check CLIProxyAPI is running: `curl http://localhost:8317/health`
2. Verify API key matches in both services
3. Check CLIProxyAPI has authenticated providers

### Connection refused to MongoDB

Wait for MongoDB to fully start (about 30 seconds), then restart LibreChat:

```bash
docker compose -f docker-compose.yml -f docker-compose.librechat.yml restart librechat
```

### Models not loading

Check CLIProxyAPI logs:

```bash
docker compose logs cli-proxy-api
```

Verify you have providers authenticated:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" http://localhost:8317/v1/models
```

## Coolify Deployment

To deploy LibreChat with CLIProxyAPI on Coolify:

1. Create a new Docker Compose resource
2. Use both compose files:
   - `docker-compose.yml`
   - `docker-compose.librechat.yml`
3. Configure environment variables in Coolify
4. Add persistent volumes for:
   - `/CLIProxyAPI/auths`
   - `/data/db` (MongoDB)
   - `/meili_data` (Meilisearch)

## Updating

```bash
# Pull latest images
docker compose -f docker-compose.yml -f docker-compose.librechat.yml pull

# Restart with new images
docker compose -f docker-compose.yml -f docker-compose.librechat.yml up -d
```

## Stopping

```bash
# Stop all services
docker compose -f docker-compose.yml -f docker-compose.librechat.yml down

# Stop and remove volumes (deletes all data)
docker compose -f docker-compose.yml -f docker-compose.librechat.yml down -v
```

## Resources

- [LibreChat Documentation](https://docs.librechat.ai/)
- [LibreChat GitHub](https://github.com/danny-avila/LibreChat)
- [LibreChat Discord](https://discord.gg/librechat)
