#!/usr/bin/env bash
set -euo pipefail

REG_NAME='registry.localhost'
REG_PORT='5000'
CLUSTER='hl-k3d'
NS='highload-dns'

# remove possibly conflicting manual containers
docker rm -f ${REG_NAME} k3d-${REG_NAME} 2>/dev/null || true

# create k3d-managed registry if it doesn't exist
if ! docker ps -a --format '{{.Names}}' | grep -q "^k3d-${REG_NAME}$"; then
  k3d registry create ${REG_NAME} --port ${REG_PORT}
fi

# create cluster that will use this registry
if ! k3d cluster list | grep -q "^${CLUSTER}\b"; then
  k3d cluster create ${CLUSTER} \
    --agents 2 \
    --k3s-arg "--disable=traefik@server:0" \
    --wait \
    --registry-use k3d-${REG_NAME}:${REG_PORT}
fi

# Connect to the registry network if the new k3d version is used (that has "k3d registry connect")
# or manually connect the docker network if the old k3d version is used (it's compatible).
if k3d registry --help 2>/dev/null | grep -q 'connect'; then
  # if new k3d version
  k3d registry connect ${REG_NAME} --cluster ${CLUSTER} || true
else
  # if old k3d version (manually connect docker network)
  docker network connect k3d-${CLUSTER} k3d-${REG_NAME} 2>/dev/null || true
fi

# create namespace
kubectl create namespace ${NS} 2>/dev/null || true

echo "Cluster '${CLUSTER}' is READY. Local registry: k3d-${REG_NAME}:${REG_PORT}"
echo "Image tags: k3d-${REG_NAME}:${REG_PORT}/<name>:local"
