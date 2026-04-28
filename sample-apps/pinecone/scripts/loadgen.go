// Load generation script for Pinecone
// This script performs continuous operations (upsert, query, fetch, delete) on a Pinecone index
// to generate metrics for monitoring and testing.
//
// Based on: https://docs.pinecone.io/guides/get-started/quickstart
//
// Usage:
//
//	export PINECONE_API_KEY="your-api-key"
//	go run loadgen.go
package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/pinecone-io/go-pinecone/v5/pinecone"
)

const (
	indexName       = "loadgen-test-index"
	dimension       = 1536             // Standard dimension for many embedding models
	numRecords      = 10               // Number of records to upsert per batch
	queryTopK       = 5                // Number of results to return per query
	operationDelay  = 5 * time.Second  // Delay between operations
	defaultDuration = 10 * time.Minute // Default run duration
)

func main() {
	apiKey := os.Getenv("PINECONE_API_KEY")
	if apiKey == "" {
		log.Fatal("PINECONE_API_KEY environment variable is required")
	}

	ctx := context.Background()
	pc, err := pinecone.NewClient(pinecone.NewClientParams{
		ApiKey: apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create Pinecone client: %v", err)
	}

	index, err := ensureIndex(ctx, pc)
	if err != nil {
		log.Fatalf("Failed to ensure index exists: %v", err)
	}

	runDuration := defaultDuration
	if durationStr := os.Getenv("PINECONE_LOADGEN_DURATION"); durationStr != "" {
		parsedDuration, err := time.ParseDuration(durationStr)
		if err == nil {
			runDuration = parsedDuration
		} else {
			log.Printf("Invalid PINECONE_LOADGEN_DURATION format, using default: %v", defaultDuration)
		}
	}

	fmt.Printf("Using index: %s\n", indexName)
	fmt.Printf("Starting load generation for %v...\n", runDuration)
	fmt.Println("This will perform upsert, query, fetch, and delete operations to generate metrics.")
	fmt.Println("Press Ctrl+C to stop early.")

	insertedIDs := make([]string, 0, 100)
	startTime := time.Now()
	deadline := startTime.Add(runDuration)

	for time.Now().Before(deadline) {
		// Upsert records
		if err := upsertRecords(ctx, index, &insertedIDs); err != nil {
			log.Printf("Error upserting records: %v", err)
		} else {
			fmt.Printf("[%s] Upserted %d records\n", time.Now().Format("15:04:05"), numRecords)
		}
		time.Sleep(operationDelay)

		// Query index
		if err := queryIndex(ctx, index); err != nil {
			log.Printf("Error querying index: %v", err)
		} else {
			fmt.Printf("[%s] Performed query\n", time.Now().Format("15:04:05"))
		}
		time.Sleep(operationDelay)

		// Fetch records (if we have any)
		if len(insertedIDs) > 0 {
			if err := fetchRecords(ctx, index, &insertedIDs); err != nil {
				log.Printf("Error fetching records: %v", err)
			} else {
				fmt.Printf("[%s] Fetched records\n", time.Now().Format("15:04:05"))
			}
		}
		time.Sleep(operationDelay)

		// Delete old records (if we have enough)
		if len(insertedIDs) >= numRecords {
			if err := deleteRecords(ctx, index, &insertedIDs); err != nil {
				log.Printf("Error deleting records: %v", err)
			} else {
				fmt.Printf("[%s] Deleted old records\n", time.Now().Format("15:04:05"))
			}
		}
		time.Sleep(operationDelay)
	}

	elapsed := time.Since(startTime)
	fmt.Printf("\nLoad generation completed. Ran for %v\n", elapsed)

	// Clean up: close index connection
	if err := index.Close(); err != nil {
		log.Printf("Warning: failed to close index connection: %v", err)
	}
}

func ensureIndex(ctx context.Context, pc *pinecone.Client) (*pinecone.IndexConnection, error) {
	indexes, err := pc.ListIndexes(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to list indexes: %w", err)
	}

	var indexInfo *pinecone.Index
	for _, idx := range indexes {
		if idx.Name == indexName {
			fmt.Printf("Index %s already exists, using it\n", indexName)
			indexInfo = idx
			break
		}
	}

	if indexInfo == nil {
		fmt.Printf("Creating new index: %s\n", indexName)
		dim := int32(dimension)
		metric := pinecone.Cosine
		_, err = pc.CreateServerlessIndex(ctx, &pinecone.CreateServerlessIndexRequest{
			Name:      indexName,
			Cloud:     pinecone.Aws,
			Region:    "us-east-1",
			Metric:    &metric,
			Dimension: &dim,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create index: %w", err)
		}

		// Wait for index to be ready (simple polling)
		fmt.Println("Waiting for index to be ready...")
		for i := 0; i < 30; i++ {
			time.Sleep(2 * time.Second)
			indexInfo, err = pc.DescribeIndex(ctx, indexName)
			if err == nil && indexInfo != nil {
				fmt.Println("Index is ready!")
				break
			}
		}
		if indexInfo == nil {
			return nil, fmt.Errorf("timeout waiting for index to be ready")
		}
	} else {
		indexInfo, err = pc.DescribeIndex(ctx, indexName)
		if err != nil {
			return nil, fmt.Errorf("failed to describe index: %w", err)
		}
	}

	indexConn, err := pc.Index(pinecone.NewIndexConnParams{
		Host: indexInfo.Host,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to index: %w", err)
	}
	return indexConn, nil
}

func upsertRecords(ctx context.Context, index *pinecone.IndexConnection, insertedIDs *[]string) error {
	vectors := make([]*pinecone.Vector, numRecords)
	categories := []string{"history", "science", "biology", "physics", "technology", "art", "geography", "literature"}

	for i := 0; i < numRecords; i++ {
		// Generate random vector
		vector := make([]float32, dimension)
		for j := range vector {
			vector[j] = rand.Float32()*2 - 1 // Random value between -1 and 1
		}

		id := fmt.Sprintf("rec%d-%d", time.Now().Unix(), i)
		category := categories[rand.Intn(len(categories))]

		metadata, err := pinecone.NewMetadata(map[string]interface{}{
			"category": category,
		})
		if err != nil {
			return fmt.Errorf("failed to create metadata: %w", err)
		}

		vectors[i] = &pinecone.Vector{
			Id:       id,
			Values:   &vector,
			Metadata: metadata,
		}

		// Track the ID for later deletion
		*insertedIDs = append(*insertedIDs, id)
	}

	_, err := index.UpsertVectors(ctx, vectors)
	return err
}

func queryIndex(ctx context.Context, index *pinecone.IndexConnection) error {
	// Generate random query vector
	queryVector := make([]float32, dimension)
	for i := range queryVector {
		queryVector[i] = rand.Float32()*2 - 1
	}

	_, err := index.QueryByVectorValues(ctx, &pinecone.QueryByVectorValuesRequest{
		Vector:          queryVector,
		TopK:            uint32(queryTopK),
		IncludeMetadata: true,
		IncludeValues:   false,
	})
	return err
}

func fetchRecords(ctx context.Context, index *pinecone.IndexConnection, insertedIDs *[]string) error {
	if len(*insertedIDs) == 0 {
		return nil
	}

	numToFetch := numRecords
	if len(*insertedIDs) < numRecords {
		numToFetch = len(*insertedIDs)
	}

	idsToFetch := make([]string, numToFetch)
	for i := 0; i < numToFetch; i++ {
		idx := rand.Intn(len(*insertedIDs))
		idsToFetch[i] = (*insertedIDs)[idx]
	}

	_, err := index.FetchVectors(ctx, idsToFetch)
	return err
}

func deleteRecords(ctx context.Context, index *pinecone.IndexConnection, insertedIDs *[]string) error {
	if len(*insertedIDs) < numRecords {
		return nil
	}

	idsToDelete := (*insertedIDs)[:numRecords]
	*insertedIDs = (*insertedIDs)[numRecords:]

	err := index.DeleteVectorsById(ctx, idsToDelete)
	return err
}
