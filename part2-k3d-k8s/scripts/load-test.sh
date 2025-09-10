#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://127.0.0.1:8081/users}"
NS="highload-dns"
ATTEMPTS="${ATTEMPTS:-20}"
DELAY="${DELAY:-0.5}"

for ((i=1; i<=ATTEMPTS; i++)); do
  raw="$(curl -s -D - "$URL" -o /tmp/resp_body.$$)" || raw=""
  body="$(cat /tmp/resp_body.$$ 2>/dev/null || echo "ERR")"
  rm -f /tmp/resp_body.$$ || true

  backend_addr="$(printf "%s" "$raw" | awk -F': ' 'BEGIN{IGNORECASE=1}/^X-Upstream-Addr:/{print $2}' | tr -d '\r')"
  [[ -z "${backend_addr}" ]] && backend_addr="unknown"

  haproxy_line="$(kubectl -n "$NS" logs deploy/haproxy --since=1s 2>/dev/null | tail -n 1 || true)"
  db_node="$(printf "%s" "$haproxy_line" | grep -o 'pg_pool/pg[0-9]\+' | cut -d'/' -f2 || true)"
  [[ -z "${db_node}" ]] && db_node="unknown"

  printf "[%02d] %s | backend=%s | db=%s | body=%s\n" \
    "$i" "$(date '+%H:%M:%S')" "$backend_addr" "$db_node" "$body"

  sleep "$DELAY"
done
