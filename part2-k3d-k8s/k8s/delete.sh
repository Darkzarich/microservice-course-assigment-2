#!/usr/bin/env bash
set -euo pipefail
kubectl delete -f k8s/nginx.yaml --ignore-not-found
kubectl delete -f k8s/backend.yaml --ignore-not-found
kubectl delete -f k8s/haproxy.yaml --ignore-not-found
kubectl delete -f k8s/postgres-replicas.yaml --ignore-not-found
kubectl delete -f k8s/postgres-primary.yaml --ignore-not-found
kubectl delete -f k8s/namespace.yaml --ignore-not-found
