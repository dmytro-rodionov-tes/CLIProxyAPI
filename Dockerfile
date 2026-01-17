FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X 'main.Version=${VERSION}-plus' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./cli-proxy-api ./cmd/server/

FROM alpine:3.23

RUN apk add --no-cache tzdata bash tar base64 curl unzip

WORKDIR /CLIProxyAPI

COPY --from=builder /app/cli-proxy-api /CLIProxyAPI/cli-proxy-api
COPY scripts /CLIProxyAPI/scripts
COPY config.example.yaml /CLIProxyAPI/config.example.yaml
COPY librechat/librechat.yaml.example /CLIProxyAPI/librechat/librechat.yaml.example

# Create directories for volume mounts
RUN mkdir -p /CLIProxyAPI/auths /CLIProxyAPI/logs /CLIProxyAPI/librechat

# Default port - can be overridden via PORT env var
EXPOSE 8317

# Timezone configuration
ENV TZ=UTC
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

# Set working directory for runtime
ENV ROOT_DIR=/CLIProxyAPI

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8317}/ || exit 1

# Use the flexible entrypoint script
# Supports: volume-mounted config, AUTH_BUNDLE, AUTH_ZIP_URL modes
CMD ["bash", "scripts/start.sh"]
