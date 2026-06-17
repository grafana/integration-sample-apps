FROM golang:1.26.4-alpine@sha256:f23e8b227fb4493eabe03bede4d5a32d04092da71962f1fb79b5f7d1e6c2a17f AS builder

WORKDIR /app
COPY go.mod go.sum main.go ./

RUN go mod tidy
RUN CGO_ENABLED=0 go build -o apache-activemq-loadgen .

FROM alpine:latest@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
COPY --from=builder /app/apache-activemq-loadgen /apache-activemq-loadgen
ENTRYPOINT ["/apache-activemq-loadgen"]
