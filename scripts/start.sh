#!/usr/bin/env bash
set -euo pipefail

# Flexible entrypoint script for CLIProxyAPI
# Supports multiple deployment modes:
#   1. Volume-mounted config (Coolify/Docker default) - mount config.yaml and auths directory
#   2. AUTH_BUNDLE mode (Railway style) - extract credentials from base64 env var
#   3. AUTH_ZIP_URL mode - download credentials from URL

info() {
  echo "[entrypoint] $*"
}

warn() {
  echo "[entrypoint] WARNING: $*" >&2
}

debug() {
  if is_truthy "${DEBUG:-false}"; then
    echo "[entrypoint][debug] $*"
  fi
}

decode_base64() {
  if base64 --help 2>&1 | grep -q -- "-d"; then
    base64 -d
  else
    base64 --decode
  fi
}

is_truthy() {
  local v="${1:-}"
  v="${v,,}"
  v="${v//[[:space:]]/}"
  case "$v" in
    1|true|t|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

ROOT_DIR="${ROOT_DIR:-$(pwd)}"
CONFIG_PATH="${CONFIG_PATH:-${ROOT_DIR}/config.yaml}"
AUTH_DIR="${AUTH_DIR:-${ROOT_DIR}/auths}"
LIBRECHAT_CONFIG_PATH="${LIBRECHAT_CONFIG_PATH:-${ROOT_DIR}/librechat/librechat.yaml}"
LIBRECHAT_CONFIG_TEMPLATE="${LIBRECHAT_CONFIG_TEMPLATE:-${ROOT_DIR}/librechat/librechat.example.yaml}"

# Determine deployment mode
MODE="volume"  # Default: expect volume-mounted config

if [[ -n "${AUTH_BUNDLE:-}" ]]; then
  MODE="auth_bundle"
elif [[ -n "${AUTH_ZIP_URL:-}" ]]; then
  MODE="auth_zip"
elif [[ -f "${CONFIG_PATH}" ]]; then
  MODE="volume"
else
  MODE="generate"
fi

info "Deployment mode: ${MODE}"

# Handle AUTH_BUNDLE mode (Railway-compatible)
if [[ "${MODE}" == "auth_bundle" ]]; then
  info "Extracting auth from AUTH_BUNDLE"
  AUTH_DIR_NAME="${AUTH_DIR_NAME:-auths}"
  AUTH_DIR="${ROOT_DIR}/${AUTH_DIR_NAME}"
  TAR_PATH="${ROOT_DIR}/auths.tar.gz"

  # Create dir and clear contents (handles mounted volumes that can't be removed)
  mkdir -p "${AUTH_DIR}"
  rm -rf "${AUTH_DIR:?}"/* "${AUTH_DIR}"/.[!.]* "${AUTH_DIR}"/..?* 2>/dev/null || true

  printf '%s' "${AUTH_BUNDLE}" | tr -d '\r\n' | decode_base64 > "${TAR_PATH}"
  tar -xzf "${TAR_PATH}" -C "${AUTH_DIR}"
  rm -f "${TAR_PATH}"

  info "Auth files extracted to ${AUTH_DIR}"
fi

# Handle AUTH_ZIP_URL mode
if [[ "${MODE}" == "auth_zip" ]]; then
  info "Downloading auth from AUTH_ZIP_URL"
  AUTH_DIR_NAME="${AUTH_DIR_NAME:-auths}"
  AUTH_DIR="${ROOT_DIR}/${AUTH_DIR_NAME}"
  ZIP_PATH="${ROOT_DIR}/auths.zip"

  # Create dir and clear contents (handles mounted volumes that can't be removed)
  mkdir -p "${AUTH_DIR}"
  rm -rf "${AUTH_DIR:?}"/* "${AUTH_DIR}"/.[!.]* "${AUTH_DIR}"/..?* 2>/dev/null || true

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${AUTH_ZIP_URL}" -o "${ZIP_PATH}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${ZIP_PATH}" "${AUTH_ZIP_URL}"
  else
    echo "Need curl or wget to fetch AUTH_ZIP_URL" >&2
    exit 1
  fi

  unzip -q "${ZIP_PATH}" -d "${AUTH_DIR}"
  rm -f "${ZIP_PATH}"

  info "Auth files extracted to ${AUTH_DIR}"
fi

# Generate config if needed (AUTH_BUNDLE, AUTH_ZIP_URL, or no config exists)
if [[ "${MODE}" != "volume" ]] || [[ ! -f "${CONFIG_PATH}" ]]; then
  # Check for required env vars when generating config
  if [[ -z "${API_KEY:-}" && -z "${API_KEY_1:-}" && -z "${API_KEYS:-}" ]]; then
    if [[ "${MODE}" != "volume" ]]; then
      warn "No API_KEY, API_KEY_1, or API_KEYS set. Using default placeholder."
    fi
  fi

  info "Generating config at ${CONFIG_PATH}"

  # Build API keys list
  API_KEYS_YAML=""
  if [[ -n "${API_KEYS:-}" ]]; then
    # API_KEYS is comma-separated
    IFS=',' read -ra KEYS <<< "${API_KEYS}"
    for key in "${KEYS[@]}"; do
      key=$(echo "$key" | xargs)  # trim whitespace
      if [[ -n "$key" ]]; then
        API_KEYS_YAML+="  - \"${key}\"\n"
      fi
    done
  elif [[ -n "${API_KEY_1:-}" ]]; then
    API_KEYS_YAML+="  - \"${API_KEY_1}\"\n"
  elif [[ -n "${API_KEY:-}" ]]; then
    API_KEYS_YAML+="  - \"${API_KEY}\"\n"
  else
    API_KEYS_YAML+="  - \"change-me-to-secure-key\"\n"
  fi

  # Server configuration
  SERVER_HOST="${SERVER_HOST:-}"
  SERVER_PORT="${PORT:-${SERVER_PORT:-8317}}"
  DEBUG="${DEBUG:-false}"

  # Management settings
  MANAGEMENT_SECRET="${MANAGEMENT_PASSWORD:-${MANAGEMENT_SECRET:-}}"
  MANAGEMENT_ALLOW_REMOTE="${MANAGEMENT_ALLOW_REMOTE:-true}"

  # Auth directory for generated config
  if [[ "${MODE}" == "auth_bundle" || "${MODE}" == "auth_zip" ]]; then
    AUTH_DIR_CONFIG="./${AUTH_DIR_NAME:-auths}"
  else
    AUTH_DIR_CONFIG="${AUTH_DIR_CONFIG:-./auths}"
  fi

  # Copilot configuration
  COPILOT_BLOCK=""
  COPILOT_ACCOUNT_TYPE="${COPILOT_ACCOUNT_TYPE:-individual}"
  COPILOT_AGENT_INITIATOR_PERSIST="${COPILOT_AGENT_INITIATOR_PERSIST:-true}"
  COPILOT_FORCE_AGENT_CALL="${COPILOT_FORCE_AGENT_CALL:-false}"

  if is_truthy "$COPILOT_AGENT_INITIATOR_PERSIST" || is_truthy "$COPILOT_FORCE_AGENT_CALL"; then
    COPILOT_BLOCK="copilot-api-key:\n"
    COPILOT_BLOCK+="  - account-type: \"${COPILOT_ACCOUNT_TYPE}\"\n"
    COPILOT_BLOCK+="    agent-initiator-persist: $(is_truthy "$COPILOT_AGENT_INITIATOR_PERSIST" && echo "true" || echo "false")\n"
    COPILOT_BLOCK+="    force-agent-call: $(is_truthy "$COPILOT_FORCE_AGENT_CALL" && echo "true" || echo "false")\n"
  fi

  cat >"${CONFIG_PATH}" <<EOF
# CLIProxyAPI Configuration
# Generated by entrypoint script

host: "${SERVER_HOST}"
port: ${SERVER_PORT}

remote-management:
  allow-remote: ${MANAGEMENT_ALLOW_REMOTE}
  secret-key: "${MANAGEMENT_SECRET}"
  disable-control-panel: false

auth-dir: "${AUTH_DIR_CONFIG}"

api-keys:
$(printf "%b" "${API_KEYS_YAML}")

debug: ${DEBUG}
logging-to-file: ${LOGGING_TO_FILE:-false}
usage-statistics-enabled: ${USAGE_STATS:-false}

proxy-url: "${PROXY_URL:-}"

request-retry: ${REQUEST_RETRY:-3}
max-retry-interval: ${MAX_RETRY_INTERVAL:-30}

quota-exceeded:
  switch-project: ${QUOTA_SWITCH_PROJECT:-true}
  switch-preview-model: ${QUOTA_SWITCH_PREVIEW:-true}

routing:
  strategy: "${ROUTING_STRATEGY:-round-robin}"

ws-auth: ${WS_AUTH:-false}
EOF

  # Append Copilot block if configured
  if [[ -n "${COPILOT_BLOCK}" ]]; then
    printf "\n%b" "${COPILOT_BLOCK}" >>"${CONFIG_PATH}"
  fi

  info "Config generated successfully"
fi

# Optionally generate LibreChat config for compose stacks (avoids committing secrets)
if is_truthy "${GENERATE_LIBRECHAT_CONFIG:-false}"; then
  if [[ ! -f "${LIBRECHAT_CONFIG_TEMPLATE}" ]]; then
    warn "LibreChat template not found at ${LIBRECHAT_CONFIG_TEMPLATE}; skipping LibreChat config generation"
    mkdir -p "$(dirname "${LIBRECHAT_CONFIG_PATH}")"
    if [[ -d "${LIBRECHAT_CONFIG_PATH}" ]]; then
      warn "LibreChat config path is a directory; resetting to a file"
      rm -rf "${LIBRECHAT_CONFIG_PATH}"
    fi
    if [[ ! -f "${LIBRECHAT_CONFIG_PATH}" ]]; then
      touch "${LIBRECHAT_CONFIG_PATH}"
      debug "Created empty LibreChat config placeholder at ${LIBRECHAT_CONFIG_PATH}"
    fi
  else
    mkdir -p "$(dirname "${LIBRECHAT_CONFIG_PATH}")"
    if [[ -d "${LIBRECHAT_CONFIG_PATH}" ]]; then
      warn "LibreChat config path is a directory; resetting to a file"
      rm -rf "${LIBRECHAT_CONFIG_PATH}"
    fi
    if [[ -f "${LIBRECHAT_CONFIG_PATH}" ]] && ! is_truthy "${OVERWRITE_LIBRECHAT_CONFIG:-false}"; then
      info "LibreChat config already exists at ${LIBRECHAT_CONFIG_PATH}; set OVERWRITE_LIBRECHAT_CONFIG=true to regenerate"
    else
      cp "${LIBRECHAT_CONFIG_TEMPLATE}" "${LIBRECHAT_CONFIG_PATH}"
      debug "Copied LibreChat template to ${LIBRECHAT_CONFIG_PATH}"
      # Optionally inline API_KEY to avoid runtime env substitution issues
      if [[ -n "${API_KEY:-}" ]] && is_truthy "${INLINE_API_KEY_IN_LIBRECHAT_CONFIG:-true}"; then
        sed -i "s#apiKey: \"\\\${API_KEY}\"#apiKey: \"${API_KEY}\"#g" "${LIBRECHAT_CONFIG_PATH}" || true
        debug "Inlined API_KEY into ${LIBRECHAT_CONFIG_PATH}"
      fi
      info "LibreChat config generated at ${LIBRECHAT_CONFIG_PATH}"
    fi
  fi
fi

# Ensure auth directory exists
mkdir -p "${AUTH_DIR}"

# Find or build the binary
BIN_PATH="${ROOT_DIR}/cli-proxy-api"

if [[ "${FORCE_BUILD:-0}" != "0" ]]; then
  info "FORCE_BUILD set; rebuilding"
  rm -f "${BIN_PATH}"
fi

if [[ ! -x "${BIN_PATH}" ]]; then
  if command -v go >/dev/null 2>&1; then
    info "Building server binary"
    go mod download
    go build -o "${BIN_PATH}" ./cmd/server
  else
    echo "Binary not found and Go not available" >&2
    exit 1
  fi
fi

info "Starting CLIProxyAPI server"
info "Config: ${CONFIG_PATH}"
info "Auth directory: ${AUTH_DIR}"

exec "${BIN_PATH}" --config "${CONFIG_PATH}"
