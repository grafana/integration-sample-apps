FROM golang:1.25.4-alpine@sha256:d3f0cf7723f3429e3f9ed846243970b20a2de7bae6a5b66fc5914e228d831bbb AS builder

WORKDIR /app
COPY go.mod go.sum main.go ./

RUN go mod tidy
RUN CGO_ENABLED=0 go build -o apache-activemq-loadgen .

FROM alpine:latest@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659
COPY --from=builder /app/apache-activemq-loadgen /apache-activemq-loadgen
ENTRYPOINT ["/apache-activemq-loadgen"]
