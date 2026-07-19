FROM --platform=linux/arm64 golang:latest@sha256:ae5a2316d12f3e78fd99177dad452e6ad4f240af2d71d57b480c3477f250fec6 as builder

WORKDIR /app


RUN apt-get update && apt-get install -y git curl jq
RUN git clone https://github.com/grafana/catchpoint-prometheus-exporter.git .
RUN git fetch origin +refs/pull/*/head:refs/remotes/origin/pr/*

# Set environment variable to build a static binary
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=arm64

# Download all dependencies
RUN go mod tidy

# Build the application as a static binary
RUN go build -ldflags '-extldflags "-static"' -o catchpoint-exporter ./cmd/catchpoint-exporter/main.go
FROM --platform=linux/arm64 alpine:latest@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b as final
WORKDIR /root/

COPY --from=builder /app/catchpoint-exporter .
EXPOSE 9090

# Configure the container to run as an executable
ENTRYPOINT ["./catchpoint-exporter"]
CMD ["--port=9090", "--webhook-path=/webhook", "--verbose"]
