#!/usr/bin/env bash
set -euo pipefail
NS="highload-dns"
URL="${1:-http://127.0.0.1:8081/users}"

phase () { echo -e "\n\n======= $* ========\n"; }
run_load () {
  ATTEMPTS="${1:-20}" DELAY="${2:-0.3}" ./scripts/load-test.sh "$URL"
}

# --- PHASE 0: baseline (2 backend, 2 replicas)
phase "PHASE 0: baseline (2 backend, 2 replicas)"
kubectl -n "$NS" scale deploy/backend --replicas=2 >/dev/null
kubectl -n "$NS" scale deploy/postgres-replicas --replicas=2 >/dev/null
sleep 3
run_load 12 0.3

# --- PHASE A: disable ONE PG replica (scale to 1)
phase "PHASE A: disable ONE PG replica (scale to 1)"
kubectl -n "$NS" scale deploy/postgres-replicas --replicas=1
sleep 3
kubectl -n "$NS" get ep postgres-replicas -o wide
run_load 20 0.3

# --- PHASE A.restore: replicas back to 2
phase "PHASE A.restore: replicas back to 2"
kubectl -n "$NS" scale deploy/postgres-replicas --replicas=2
sleep 3
kubectl -n "$NS" get ep postgres-replicas -o wide
run_load 12 0.3

# --- PHASE B: disable ONE backend (scale to 1)
phase "PHASE B: disable ONE backend (scale to 1)"
kubectl -n "$NS" scale deploy/backend --replicas=1
sleep 3
kubectl -n "$NS" get ep backend-headless -o wide
run_load 20 0.3

# --- PHASE B.restore: backend back to 2
phase "PHASE B.restore: backend back to 2"
kubectl -n "$NS" scale deploy/backend --replicas=2
sleep 3
kubectl -n "$NS" get ep backend-headless -o wide
run_load 12 0.3

# --- PHASE C: single backend + single replica, then delete ONLY backend pod
phase "PHASE C: 1 backend + 1 PG replica, then delete the ONLY backend pod (observe errors -> recovery)"
# leave just one instance of each
kubectl -n "$NS" scale deploy/backend --replicas=1
kubectl -n "$NS" scale deploy/postgres-replicas --replicas=1
sleep 3
echo "# Endpoints now:"
kubectl -n "$NS" get ep backend-headless -o wide
kubectl -n "$NS" get ep postgres-replicas -o wide

# control measurement: everything is stable (1 backend, 1 replica)
run_load 10 0.3

# removing the only pod with the backend (ReplicaSet will recreate it)
phase "PHASE C.drop: deleting the only backend pod"
ONE_BACKEND="$(kubectl -n "$NS" get pod -l app=backend -o name | head -n1)"
echo "Deleting $ONE_BACKEND ..."
kubectl -n "$NS" delete "$ONE_BACKEND" --wait=false

# right after finishing: expecting to see several errors with several attempts
# (until the new pod downloads an image/start/readiness check fill finish)
run_load 15 0.3

# waiting until the deployment is restored and test again
phase "PHASE C.restore: waiting for backend rollout, then verify"
kubectl -n "$NS" rollout status deploy/backend
kubectl -n "$NS" get ep backend-headless -o wide
run_load 12 0.3

phase "DONE"
