#!/usr/bin/env bash
set -euo pipefail
: "${PRIMARY_SERVICE:=postgres-primary}"
: "${REPL_USER:=repl}"
: "${REPL_PASSWORD:=repl}"

until getent hosts "${PRIMARY_SERVICE}"; do
  echo "Waiting for DNS ${PRIMARY_SERVICE}..."; sleep 1; done
PRIMARY_HOST=$(getent hosts "${PRIMARY_SERVICE}" | awk '{print $1}')
echo "Primary resolved to ${PRIMARY_HOST}"

export PGPASSWORD="${REPL_PASSWORD}"
until pg_isready -h "${PRIMARY_HOST}" -p 5432 -U "${REPL_USER}"; do
  echo "Waiting for primary PostgreSQL..."; sleep 2; done

if [ -z "$(ls -A "${PGDATA}")" ]; then
  echo "Cloning basebackup from primary..."
  pg_basebackup -h "${PRIMARY_HOST}" -D "${PGDATA}" -U "${REPL_USER}" -Fp -Xs -P -R
  echo "primary_conninfo = 'host=${PRIMARY_HOST} port=5432 user=${REPL_USER} password=${REPL_PASSWORD}'" >> "${PGDATA}/postgresql.auto.conf"
  touch "${PGDATA}/standby.signal"
  chown -R postgres:postgres "${PGDATA}"
fi
echo "hot_standby = on" >> "${PGDATA}/postgresql.conf"
exec docker-entrypoint.sh postgres
