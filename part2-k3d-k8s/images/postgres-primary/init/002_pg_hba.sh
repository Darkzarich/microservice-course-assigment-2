#!/usr/bin/env bash
set -euo pipefail
PGDATA="${PGDATA:-/var/lib/postgresql/data}"
cat >> "${PGDATA}/pg_hba.conf" <<'HBA'
# Allow replication and access to the application from the k3d pod subnet (DEFAULT is 10.42.0.0/16 !!!)
host replication repl 10.42.0.0/16 scram-sha-256
host appdb      app  10.42.0.0/16 scram-sha-256
HBA
