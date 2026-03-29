FROM --platform=linux/arm64 golang:latest@sha256:595c7847cff97c9a9e76f015083c481d26078f961c9c8dca3923132f51fe12f1 as builder

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
FROM --platform=linux/arm64 alpine:latest@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412 as final
WORKDIR /root/

COPY --from=builder /app/catchpoint-exporter .
EXPOSE 9090

# Configure the container to run as an executable
ENTRYPOINT ["./catchpoint-exporter"]
CMD ["--port=9090", "--webhook-path=/webhook", "--verbose"]
