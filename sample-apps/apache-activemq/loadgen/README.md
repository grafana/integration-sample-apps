# Apache ActiveMQ Load Generator

Simple Go based load generator that creates message traffic for the ActiveMQ sample app. Runs as a CronJob every 2 minutes to generate metrics.

## What it does

- Connects to ActiveMQ via AMQP on port 5672
- Creates producers and consumers for 2 topics and 2 queues
- Sends "Hello World!" messages every 50ms for 1 minute
- Consumers read messages with 1s delays to simulate backpressure

## Configuration

Default config in `main.go`:
```go
Host: "apache-activemq"  // K8s service name
Port: "5672"             // AMQP port
Username/Password: "admin/admin"
Topics: ["topic://test-topic-1", "topic://test-topic-2"]
Queues: ["queue://test-queue-1", "queue://test-queue-2"]
```

## Usage

Built and deployed automatically by the parent sample app. Modify `defaultConfig()` in `main.go` to change behavior.
