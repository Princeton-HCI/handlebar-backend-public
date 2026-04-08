# Fresh Database Setup

Steps to initialize a new Cloud SQL instance with the legacy schema and run migrations.

## Prereqs

- `cloud-sql-proxy` installed and authenticated (`gcloud auth application-default login`)
- `psql` installed
- Elixir 1.14.0 / OTP 25 (see `.tool-versions`)

## Env vars

```sh
export CLOUD_SQL_CONNECTION_ID="up-ist-wao:us-east1:handlebar-db"
export DB_HOST="127.0.0.1"
export DB_PORT="5432"
export DB_NAME="handlebar"           # the database within the instance
export DB_PASSWORD="<postgres-password>"
export PGPASSWORD="$DB_PASSWORD"     # for psql
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export MIX_ENV=prod
```

## 1. Tunnel to Cloud SQL

```sh
cloud-sql-proxy "$CLOUD_SQL_CONNECTION_ID" &
```

Leave running in another shell or background it.

## 2. Load the legacy schema

`priv/repo/structure.sql` contains the full DSC schema plus the `schema_migrations` rows for every prior migration, so Ecto will treat them as already-applied.

```sh
psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" -f priv/repo/structure.sql
```

## 3. Run new migrations

```sh
mix deps.get
mix ecto.migrate
```

Verify:

```sh
psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" -c "\dt" | grep research_group
```

## Notes

- Do **not** run `mix ecto.create` against the prod instance — the database already exists.
- `config/runtime.exs` uses `DB_HOST`/`DB_PORT` when set (local proxy); otherwise falls back to the Cloud Run unix socket at `/cloudsql/$CLOUD_SQL_CONNECTION_ID`.
