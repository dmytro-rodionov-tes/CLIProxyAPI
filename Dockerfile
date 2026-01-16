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

RUN apk add --no-cache tzdata bash tar base64

RUN mkdir /CLIProxyAPI

COPY --from=builder /app/cli-proxy-api /CLIProxyAPI/cli-proxy-api

COPY scripts /CLIProxyAPI/scripts
COPY config.example.yaml /CLIProxyAPI/config.example.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Europe/London

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

CMD ["bash", "scripts/railway_start.sh"]
