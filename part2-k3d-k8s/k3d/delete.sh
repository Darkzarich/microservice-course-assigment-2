#!/usr/bin/env bash
set -euo pipefail
CLUSTER='hl-k3d'
REG_NAME='registry.localhost'
k3d cluster delete ${CLUSTER} || true
docker rm -f k3d-${REG_NAME} || true
