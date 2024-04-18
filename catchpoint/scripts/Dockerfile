# Use a Go image as the base image
FROM --platform=linux/arm64 golang:latest as builder


WORKDIR /app
RUN git clone https://github.com/JonathanWamsley/catchpoint-prometheus-exporter.git .

# Set environment variable to build a static binary
ENV CGO_ENABLED=0
ENV GOOS=linux
# ENV GOARCH=amd64
ENV GOARCH=arm64

# Download all dependencies
RUN go mod tidy

# Build the application as a static binary
RUN go build -ldflags '-extldflags "-static"' -o catchpoint-exporter ./cmd/catchpoint-exporter/main.go

# Use a minimal base image from scratch
# FROM scratch
FROM --platform=linux/arm64 alpine:latest as final
WORKDIR /root/

# Install basic tools
RUN apk add --no-cache bash

COPY --from=builder /app/catchpoint-exporter .
EXPOSE 8080
ENTRYPOINT ["./catchpoint-exporter"]
CMD ["--bearer-token=yourtoken", "--node-ids=1,2"]