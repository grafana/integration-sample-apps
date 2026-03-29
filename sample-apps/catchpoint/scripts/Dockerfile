FROM --platform=linux/arm64 golang:latest@sha256:e68f6a00e88586577fafa4d9cefad1349c2be70d21244321321c407474ff9bf2 as builder

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
FROM --platform=linux/arm64 alpine:latest@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 as final
WORKDIR /root/

COPY --from=builder /app/catchpoint-exporter .
EXPOSE 9090

# Configure the container to run as an executable
ENTRYPOINT ["./catchpoint-exporter"]
CMD ["--port=9090", "--webhook-path=/webhook", "--verbose"]
