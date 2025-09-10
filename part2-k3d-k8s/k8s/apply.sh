#!/usr/bin/env bash
set -euo pipefail
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres-primary.yaml
kubectl apply -f k8s/postgres-replicas.yaml
kubectl apply -f k8s/haproxy.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/nginx.yaml
