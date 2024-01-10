#!/bin/bash

export INGRESS_NAME=istio-ingress
export INGRESS_NS=istio-ingress
export INGRESS_HOST=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "Generating Load"
while true; do
    curl -s -o /dev/null "http://$GATEWAY_URL/productpage"
    curl -s -o /dev/null "http://$GATEWAY_URL/productpage"
    curl -s -o /dev/null "http://$GATEWAY_URL/bad"
    curl -s -o /dev/null "http://$GATEWAY_URL/api/v1/products/bad"
    sleep 1
done
