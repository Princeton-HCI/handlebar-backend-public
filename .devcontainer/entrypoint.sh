#!/bin/bash

DB_USER=${DATABASE_USER:-postgres}

# while ! pg_isread -q -h $DATABASE_HOST -p 5432 -U $DB_USER
# do
#     echo "$(date) - waiting for database to start"
#     sleep 2
# done

# bin="/app/bin/milk"
#eval "$bin eval \"Milk.Release.migrate\""
# MIX_ENV=prod
# mix local.hex --force
# mix local.rebar --force
# mix deps.get
mix ecto.create &&\
mix ecto.migrate &&\
mix run priv/repo/seeds.exs


# mix ecto.create
# mix ecto.migrate
echo "migrated"

# start the elixir application
mix phx.server
