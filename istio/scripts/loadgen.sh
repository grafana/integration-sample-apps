#!/bin/bash

export INGRESS_NAME=istio-ingress
export INGRESS_NS=istio-ingress
export INGRESS_HOST=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export TCP_INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

while true; do
    curl -s -o /dev/null "http://$GATEWAY_URL/productpage"
    curl -s -o /dev/null "http://$GATEWAY_URL/productpage"
    curl -s -o /dev/null "http://$GATEWAY_URL/bad"
done
