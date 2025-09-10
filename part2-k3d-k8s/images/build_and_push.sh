#!/usr/bin/env bash
set -euo pipefail
REG="k3d-registry.localhost:5000"

declare -A IMAGES=(
  ["backend"]="images/backend"
  ["postgres-primary"]="images/postgres-primary"
  ["postgres-replica"]="images/postgres-replica"
  ["haproxy"]="images/haproxy"
  ["nginx"]="images/nginx"
)

for name in "${!IMAGES[@]}"; do
  dir="${IMAGES[$name]}"
  echo "==> Building $name"
  docker build --platform=linux/amd64 -t "${REG}/${name}:local" "$dir"
  echo "==> Pushing ${REG}/${name}:local"
  docker push "${REG}/${name}:local"
done

echo "All images pushed to ${REG}"
