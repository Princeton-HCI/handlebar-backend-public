# UPDATE FROM DSC API + MIGRATION NOTES

This is the result of a migration kicked off by Andrew in October '25 to
create a Handlebar API that excluded all unused functionality from the
original DSC.

## Current state

## TODOs

### Database configuration
Right now there is an empty database with no migrations created at `princeton-hci-wao-dsc:us-east1:handlebar-db`.

Migrations have been squashed into `structure.sql`.

To set up the new database, run:

```
mix ecto.create
mix ecto.load
```

This will load in the schema from `structure.sql`.

Future migrations can be done using `mix ecto.gen.migration`.

- [x] Run `ecto.create` and `ecto.load` on the database to stand up migrations

### Other setup
- [x] Continue removing unused code
- [x] Update routing and endpoints in the handlebar app to use /handlebar instead of /crepe -to be done today
- [ ] Include database migrations in the build pipeline (see `run_google_cloud_migrations.sh` for an example)
- [x] Create a test database and test Cloud Run instance
- [ ] ~~I highly recommend **using a custom domain or subdomain** so that future updates can be done without managing different URLs on different app versions. This will also facilitate configuring a firewall, load balancers, etc. if needed later on.~~
- [x] Cut over the current Handlebar deploy to point at this new URL
- [x] Move `SECRET_KEY_BASE` to [Secret Manager](https://cloud.google.com/security/products/secret-manager?hl=en)
- [x] Move database password to [Secret Manager](https://cloud.google.com/security/products/secret-manager?hl=en)

# Drivers Seat Coop Web and API

Related Projects:

- [Mobile Application (dsc-mobile)](https://github.com/Princeton-HCI/dsc-mobile)

The API server:

- Provides an API interface for the app
- Host static content (for marketing campaigns and for help)

## Tech Stack

This project uses:

- [PostgreSQL](https://www.postgresql.org/) as the back-end database
- [Elixir](https://elixir-lang.org) as the back-end language
- [Phoenix](https://www.phoenixframework.org) as the web framework
- [Oban](https://getoban.pro) for background job processing
- Google Cloud for deployment

## External Services

This project uses:

- [Mixpanel](https://mixpanel.com/)
- [Sentry](https://sentry.io/welcome/)
- [OneSignal](https://onesignal.com/)

## Getting Started

- [Setting-up a Development Environment](/docs/developer_setup/README.md)
- [Environment Variables](/docs/environment_variables/README.md)
- [Populating Geosptial Referece Data](/docs/populating_geographies/README.md)

## Deployment

- Code is hosted on GitHub
- The deployment is from Google Cloud
- There is a staging and a production environemnt
- Databases are in Google Cloud SQL

### CI / CD pipeline

- New commits to main will trigger new builds via Cloud Build
- Builds in Cloud Build will deploy to Cloud Run
- `main` corresponds to the production deployment. Merges to `main` will auto-build to production.
- `staging` corresponds to the staging deployment. Merges to `staging` will auto-build to staging.

### Running migrations after merging to main

The `run_google_cloud_migrations.sh` helper script will create a Cloud Run job
to make migrations run. This should be invoked upon merging in a change that
has migrations.

TODO: it should be part of the CI pipeline.

If needed, you can then connect to the database via a tunnel with:

```
gcloud auth login
gcloud auth application-default login

# production
./cloud-sql-proxy princeton-hci-wao-dsc:us-central1:drivers-seat --port 54322

# staging
./cloud-sql-proxy princeton-hci-wao-dsc:us-central1:dsc-staging --port 54300
```
