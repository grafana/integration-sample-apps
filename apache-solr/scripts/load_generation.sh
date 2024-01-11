#!/bin/bash

# Configuration
SOLR_HOST="localhost"
SOLR_PORT="8983"
COLLECTION="cluster-collection"
NUM_DOCS=10 # Number of documents to index
SLEEP_DURATION=600 # 10 minutes in seconds

while true; do
    # Function to index documents
    index_docs() {
        echo "Indexing $NUM_DOCS documents..."
        for ((i=1; i<=NUM_DOCS; i++)); do
            curl -X POST "http://$SOLR_HOST:$SOLR_PORT/solr/$COLLECTION/update/json/docs" \
                 -H 'Content-type:application/json' \
                 -d '[{"id":"'"$i"'", "title":"Title '"$i"'", "content":"Content for document '"$i"'"}]'
        done
        # Commit the changes
        curl -X POST "http://$SOLR_HOST:$SOLR_PORT/solr/$COLLECTION/update" -d '<commit/>'
        echo "Indexing completed."
    }

    # Function to perform queries
    perform_queries() {
        echo "Performing queries..."
        for ((i=1; i<=NUM_DOCS; i++)); do
            curl "http://$SOLR_HOST:$SOLR_PORT/solr/$COLLECTION/select?q=id:$i"
            echo ""
        done
        echo "Queries completed."
    }

    # Function to delete documents
    delete_docs() {
        echo "Deleting documents..."
        curl -X POST "http://$SOLR_HOST:$SOLR_PORT/solr/$COLLECTION/update" -d '<delete><query>*:*</query></delete>'
        # Commit the changes
        curl -X POST "http://$SOLR_HOST:$SOLR_PORT/solr/$COLLECTION/update" -d '<commit/>'
        echo "Deletion completed."
    }

    # Execute functions
    index_docs
    perform_queries
    delete_docs

    # Sleep for 10 minutes before next iteration
    sleep $SLEEP_DURATION
done
