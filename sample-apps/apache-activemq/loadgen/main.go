package main

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/Azure/go-amqp"
)

const topicOne = "topic://test-topic-1"
const topicTwo = "topic://test-topic-2"
const queueOne = "queue://test-queue-1"
const queueTwo = "queue://test-queue-2"

type Config struct {
	Host          string        `yaml:"host"`
	Port          string        `yaml:"port"`
	Username      string        `yaml:"username"`
	Password      string        `yaml:"password"`
	SendInterval  time.Duration `yaml:"send_interval"`
	SendTimeout   time.Duration `yaml:"send_timeout"`
	ReceiverSleep time.Duration `yaml:"receiver_sleep"`

	Topics []string `yaml:"topics"`
	Queues []string `yaml:"queues"`
}

type loadGenerator struct {
	config Config
	cancel context.CancelFunc
}

func defaultConfig() Config {
	return Config{
		Host:          "apache-activemq",
		Port:          "5672",
		Username:      "admin",
		Password:      "admin",
		SendInterval:  50 * time.Millisecond,
		SendTimeout:   1 * time.Minute,
		ReceiverSleep: 1 * time.Second,

		Topics: []string{topicOne, topicTwo},
		Queues: []string{queueOne, queueTwo},
	}
}

// startProducers starts a producer for each topic and queue.
func (lg *loadGenerator) startProducers(ctx context.Context, wg *sync.WaitGroup) {
	for _, topic := range lg.config.Topics {
		wg.Add(1)
		go lg.startProducer(ctx, topic, wg)
	}

	for _, queue := range lg.config.Queues {
		wg.Add(1)
		go lg.startProducer(ctx, queue, wg)
	}
}

// startProducer starts a producer for a given destination.
func (lg *loadGenerator) startProducer(ctx context.Context, destination string, wg *sync.WaitGroup) {
	defer wg.Done()

	conn, err := amqp.Dial(ctx, lg.hostAddress(), nil)
	if err != nil {
		log.Fatal("Connection to server failed:", err)
	}
	defer conn.Close()

	session, err := conn.NewSession(ctx, nil)
	if err != nil {
		log.Fatal("Failed to open a session:", err)
	}
	defer session.Close(ctx)

	sender, err := session.NewSender(ctx, destination, nil)
	if err != nil {
		log.Fatal("Failed to create new sender:", err)
	}
	defer sender.Close(ctx)

	ticker := time.NewTicker(lg.config.SendInterval)
	defer ticker.Stop()

	ctxWithTimeout, cancel := context.WithTimeout(ctx, lg.config.SendTimeout)
	defer cancel()

sendLoop:
	for {
		select {
		case <-ctxWithTimeout.Done():
			break sendLoop
		case <-ticker.C:
			err = sender.Send(ctx, amqp.NewMessage([]byte("Hello World!")), &amqp.SendOptions{})
			if err != nil {
				log.Fatal("Failed to send message:", err)
			}
		}
	}

	sender.Close(ctx)
	log.Printf("Producer for %s closed", destination)
}

// startReceivers starts receivers for each topic and queue.
func (lg *loadGenerator) startReceivers(ctx context.Context) {
	for _, topic := range lg.config.Topics {
		go lg.startReceiver(ctx, topic)
	}

	for _, queue := range lg.config.Queues {
		go lg.startReceiver(ctx, queue)
	}
}

// startReceiver starts a receiver for a given destination.
func (lg *loadGenerator) startReceiver(ctx context.Context, destination string) {
	conn, err := amqp.Dial(ctx, lg.hostAddress(), nil)
	if err != nil {
		log.Fatal("Connection to server failed:", err)
	}
	defer conn.Close()

	session, err := conn.NewSession(ctx, nil)
	if err != nil {
		log.Fatal("Failed to open a session:", err)
	}
	defer session.Close(ctx)

	receiver, err := session.NewReceiver(ctx, destination, nil)
	if err != nil {
		log.Fatal("Failed to create new receiver:", err)
	}
	defer receiver.Close(ctx)

	for {
		select {
		case <-ctx.Done():
			return
		default:
			// sleeping to simulate backpressure
			time.Sleep(lg.config.ReceiverSleep)
			msg, err := receiver.Receive(ctx, nil)
			if err != nil {
				log.Fatal("Failed to receive message:", err)
			}
			receiver.AcceptMessage(ctx, msg)
			fmt.Printf("Message received: %s\n", msg.GetData())
		}
	}
}

func (lg *loadGenerator) hostAddress() string {
	return fmt.Sprintf("amqp://%s:%s@%s:%s", lg.config.Username, lg.config.Password, lg.config.Host, lg.config.Port)
}

func main() {
	var wg sync.WaitGroup
	ctx, cancel := context.WithCancel(context.Background())
	lg := loadGenerator{config: defaultConfig(), cancel: cancel}
	lg.startReceivers(ctx)
	lg.startProducers(ctx, &wg)
	fmt.Println("Waiting for goroutines to finish...")
	wg.Wait()
	fmt.Println("Done!")
	lg.cancel()
}
