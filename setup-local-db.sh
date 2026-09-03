#!/usr/bin/env bash
# Bootstrap a local Handlebar database (dev or test).
#
# The migration chain alone CANNOT build a working database:
#   - The legacy Driver's Seat schema (users, points, crepe_collector, regions,
#     terms, ...) lives only in priv/repo/structure.sql, not in migrations.
#   - Migrations reference those tables (e.g. research_group_collectors ->
#     crepe_collector, points.membership_id), so they fail on an empty DB.
#   - Migration 20260427204332 inserts Terms with a hardcoded user_id = 1, so a
#     user with id 1 must exist BEFORE migrating. seeds.exs runs after
#     migrations and is therefore too late.
#   - structure.sql needs the postgis and citext extensions available.
#
# Correct order: create -> structure.sql -> seed user 1 -> migrate.
#
# Usage:  ./setup-local-db.sh [handlebar_test|handlebar_dev]
set -euo pipefail

DB="${1:-handlebar_test}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
export PGHOST PGPORT PGUSER

case "$DB" in
  *_test) MIX_ENV=test ;;
  *)      MIX_ENV=dev  ;;
esac
export MIX_ENV

echo "==> Checking postgres at $PGHOST:$PGPORT"
pg_isready -h "$PGHOST" -p "$PGPORT" >/dev/null || {
  echo "postgres is not running. Start it with:  brew services start postgresql@18" >&2
  exit 1
}

echo "==> Checking postgis is available"
psql -d postgres -tAc "select 1 from pg_available_extensions where name='postgis'" | grep -q 1 || {
  echo "postgis not available to this server. Install with:  brew install postgis" >&2
  exit 1
}

echo "==> Recreating database $DB"
psql -d postgres -c "DROP DATABASE IF EXISTS $DB;" >/dev/null
psql -d postgres -c "CREATE DATABASE $DB;" >/dev/null

echo "==> Loading legacy schema (priv/repo/structure.sql)"
psql -d "$DB" -v ON_ERROR_STOP=1 -q -f priv/repo/structure.sql

echo "==> Seeding system user id=1 (required by the initial-terms migration)"
psql -d "$DB" -q -c \
  "INSERT INTO users (id, email, inserted_at, updated_at)
   VALUES (1, 'system@handlebar.local', NOW(), NOW())
   ON CONFLICT (id) DO NOTHING;"
psql -d "$DB" -qtAc \
  "SELECT setval(pg_get_serial_sequence('users','id'), GREATEST((SELECT MAX(id) FROM users), 1));" >/dev/null

echo "==> Running migrations (MIX_ENV=$MIX_ENV)"
POSTGRES_DB="$DB" mix ecto.migrate

echo "==> Done. $DB is ready."
