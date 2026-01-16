# Coolify Deployment Guide

Deploy CLIProxyAPI to Coolify in under 5 minutes.

## Prerequisites

- Coolify instance running
- Git repository URL (or fork this repo)

## Quick Setup (3 Steps)

### Step 1: Create New Resource

1. Go to your Coolify dashboard
2. Click **"+ Add Resource"** → **"Docker Compose"**
3. Select your server and choose **"Public Repository"**
4. Enter repository URL: `https://github.com/YOUR_USERNAME/CLIProxyAPI.git`
5. Set branch to `main`

### Step 2: Configure Environment Variables

In the **Environment Variables** section, add:

```env
# REQUIRED - Your API key for authenticating clients
API_KEY=your-secure-api-key-here

# RECOMMENDED - Enables web management UI at /management.html
MANAGEMENT_PASSWORD=your-management-password
MANAGEMENT_ALLOW_REMOTE=true
```

### Step 3: Configure Storage

In the **Storages** section, add persistent volumes:

| Name | Mount Path | Description |
|------|------------|-------------|
| `auths` | `/CLIProxyAPI/auths` | OAuth tokens (required for persistent logins) |
| `logs` | `/CLIProxyAPI/logs` | Application logs |

Click **Deploy** and you're done!

---

## Accessing Your Instance

After deployment:

- **API Endpoint**: `https://your-domain.com/v1/chat/completions`
- **Management UI**: `https://your-domain.com/management.html`

### Test the API

```bash
curl https://your-domain.com/v1/models \
  -H "Authorization: Bearer your-secure-api-key-here"
```

---

## Adding AI Provider Credentials

### Option A: Via Management UI (Recommended)

1. Open `https://your-domain.com/management.html`
2. Enter your management password
3. Use the UI to add OAuth logins for Claude, Gemini, Copilot, etc.

### Option B: Local Auth + Upload

1. Run locally to authenticate:
```bash
# Build and run locally
go build -o cli-proxy-api ./cmd/server/
./cli-proxy-api -claude-login    # For Claude
./cli-proxy-api -copilot-login   # For GitHub Copilot
./cli-proxy-api -login           # For Gemini
```

2. Package credentials:
```bash
cd ~/.cli-proxy-api
tar -czf - . | base64 > auth_bundle.txt
```

3. In Coolify, add environment variable:
```env
AUTH_BUNDLE=<paste contents of auth_bundle.txt>
```

4. Redeploy the service

---

## Environment Variables Reference

### Required

| Variable | Description |
|----------|-------------|
| `API_KEY` | API key for client authentication |

### Recommended

| Variable | Default | Description |
|----------|---------|-------------|
| `MANAGEMENT_PASSWORD` | _(empty)_ | Enables management UI |
| `MANAGEMENT_ALLOW_REMOTE` | `true` | Allow remote management access |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | `false` | Enable debug logging |
| `REQUEST_RETRY` | `3` | Number of retry attempts |
| `ROUTING_STRATEGY` | `round-robin` | Credential selection (`round-robin` or `fill-first`) |
| `TZ` | `UTC` | Container timezone |
| `PROXY_URL` | _(empty)_ | HTTP/SOCKS5 proxy URL |

### Credential Transfer

| Variable | Description |
|----------|-------------|
| `AUTH_BUNDLE` | Base64-encoded tar.gz of auth directory |
| `AUTH_ZIP_URL` | URL to download auth credentials zip |

---

## Using with AI Coding Tools

### Claude Code

```bash
export ANTHROPIC_BASE_URL="https://your-domain.com"
export ANTHROPIC_API_KEY="your-secure-api-key-here"
claude
```

### Cursor / Continue / Other OpenAI-compatible tools

Set base URL to: `https://your-domain.com/v1`
Set API key to: `your-secure-api-key-here`

---

## Troubleshooting

### Container won't start

Check logs in Coolify. Common issues:
- Missing `API_KEY` environment variable
- Port conflict (default is 8317)

### Auth tokens not persisting

Ensure the `/CLIProxyAPI/auths` volume is configured as persistent storage in Coolify.

### Management UI returns 404

Set `MANAGEMENT_PASSWORD` environment variable and redeploy.

### Health check failing

The health check hits `/` on port 8317. Ensure:
- Container has finished starting (wait ~10 seconds)
- No firewall blocking internal container communication

---

## Updating

To update to the latest version:

1. Go to your service in Coolify
2. Click **"Redeploy"** or **"Pull & Redeploy"**

Your auth tokens and configuration will persist in the mounted volumes.
