FROM golang:1.26.11-alpine@sha256:ecb67f987aa1a57794c91d19ade7ae0209f2f0f5496aaef9e6ae85ddf92d02ab AS builder

WORKDIR /app
COPY go.mod go.sum main.go ./

RUN go mod tidy
RUN CGO_ENABLED=0 go build -o apache-activemq-loadgen .

FROM alpine:latest@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
COPY --from=builder /app/apache-activemq-loadgen /apache-activemq-loadgen
ENTRYPOINT ["/apache-activemq-loadgen"]
