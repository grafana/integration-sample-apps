FROM golang:1.26.10-alpine@sha256:87c65a688975c0b1d4585d204874c45ca78354670e3a5f11368c5a492303d696 AS builder

WORKDIR /app
COPY go.mod go.sum main.go ./

RUN go mod tidy
RUN CGO_ENABLED=0 go build -o apache-activemq-loadgen .

FROM alpine:latest@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
COPY --from=builder /app/apache-activemq-loadgen /apache-activemq-loadgen
ENTRYPOINT ["/apache-activemq-loadgen"]
