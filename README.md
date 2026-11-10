# Handlebar Backend

Handlebar is an Android app that records screens during gig delivery work (DoorDash, Uber Eats, Grubhub, etc.) and lets researchers build "collectors" that turn those recordings into structured data. This repository is the backend API that the Handlebar mobile app talks to: it handles user authentication, study and collector management, uploaded data, and researcher-facing admin tooling.

Related repositories:

- [`handlebar`](https://github.com/Princeton-HCI/handlebar) — the Flutter mobile app
- [`crepe-flutter-plugin`](https://github.com/Princeton-HCI/crepe-flutter-plugin) — the screen-recording/collector plugin the app depends on

This project started as a fork of [Driver's Seat Cooperative](https://driversseat.co)'s backend, with functionality unrelated to Handlebar removed. Some internal module and app names (`DriversSeatCoop`, `:dsc`) are left over from that history (for now).

## Tech Stack

- [Elixir](https://elixir-lang.org) / [Phoenix](https://www.phoenixframework.org)
- [PostgreSQL](https://www.postgresql.org/) with [PostGIS](https://postgis.net/)
- [Oban](https://hexdocs.pm/oban/Oban.html) for background jobs
- Google Cloud Run / Cloud SQL in production (see [Deployment](#deployment))

### External services (optional in development)

The app integrates with a few third-party services. None of these are required to run the server locally — each degrades gracefully or can be left unconfigured in dev/test:

- [SendGrid](https://sendgrid.com/) — outbound email (password resets, data export links, help requests)
- [Mixpanel](https://mixpanel.com/) — usage analytics and population segmentation
- [OneSignal](https://onesignal.com/) — push notifications
- [Sentry](https://sentry.io/) — error reporting
- [Backblaze B2](https://www.backblaze.com/cloud-storage) — storage for user data export files

## Prerequisites

- [Homebrew](https://brew.sh/) (macOS)
- [asdf](https://asdf-vm.com/) for managing Erlang/Elixir versions
- PostgreSQL with the PostGIS extension
- Node.js (for asset building)

```shell
brew install asdf node postgresql postgis
echo -e '\n. /opt/homebrew/opt/asdf/libexec/asdf.sh' >> ~/.zshrc
```

Make sure you have a local `postgres` role with password `postgres`, or adjust `DATABASE_URL` accordingly (see [Environment Variables](docs/environment_variables/README.md)).

Install Erlang and Elixir via asdf (open a new shell first):

```shell
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 25.3.2.7
asdf install elixir 1.14.0-otp-25
asdf global erlang 25.3.2.7
asdf global elixir 1.14.0-otp-25
```

On Apple Silicon, see the [asdf-erlang OpenSSL notes](https://github.com/asdf-vm/asdf-erlang?tab=readme-ov-file#dealing-with-openssl-issues-on-macos) if the Erlang install fails.

## Getting Started

1. Clone this repo and fetch dependencies:

   ```shell
   mix deps.get
   ```

2. Create and migrate the database:

   ```shell
   mix ecto.create
   mix ecto.migrate
   ```

3. Seed an initial admin user and terms-of-service record. This is required before the mobile app can connect, since it requires an accepted terms of service.

   ```shell
   mix run priv/repo/seeds.exs
   ```

4. (Optional) Load geospatial reference data used for metro-area assignment. See [Populating Geographic Data](docs/populating_geographies/README.md).

5. Start the server:

   ```shell
   mix phx.server
   ```

   - API: `http://localhost:4000`
   - Admin site: `http://localhost:4000/_admin`

See [Environment Variables](docs/environment_variables/README.md) for the full list of configuration options, and [Developer Setup](docs/developer_setup/README.md) for more detailed platform-specific notes.

## Running Tests

```shell
mix test
```

This creates and uses a separate `handlebar_test` database.

## Code Quality

```shell
mix format
mix credo --strict --all
```

## Background Jobs (Oban)

Background work runs through [Oban](https://hexdocs.pm/oban/Oban.html). In development, most queues are disabled by default since many jobs call external services. Enable specific queues with:

```shell
export OBAN_QUEUES="update_timespans_for_user:1 update_timespans_for_user_workday:2 goals:2"
```

## Deployment

The production and staging services run on Google Cloud Run, backed by Cloud SQL (PostgreSQL). Merges to `main` deploy to production; merges to `staging` deploy to staging, both via Cloud Build. Database migrations run via a Cloud Run job (see `run_google_cloud_migrations.sh`). Deployment is specific to the current maintainers' GCP project; reach out to the maintainers if you need to stand up your own hosted instance.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
