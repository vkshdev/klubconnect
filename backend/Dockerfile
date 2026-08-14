FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY cmd/ cmd/
COPY internal/ internal/

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/worker ./cmd/worker

FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /app/worker /app/worker

USER appuser:appgroup

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -q --spider http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/app/worker"]
