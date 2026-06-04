FROM golang:1.25.4-alpine@sha256:d3f0cf7723f3429e3f9ed846243970b20a2de7bae6a5b66fc5914e228d831bbb AS builder

WORKDIR /app
COPY go.mod go.sum main.go ./

RUN go mod tidy
RUN CGO_ENABLED=0 go build -o apache-activemq-loadgen .

FROM alpine:latest@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11
COPY --from=builder /app/apache-activemq-loadgen /apache-activemq-loadgen
ENTRYPOINT ["/apache-activemq-loadgen"]
