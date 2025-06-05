# Drivers Seat Coop Web and API

Related Projects:

- [Mobile Application (dsc-mobile)](https://github.com/Princeton-HCI/dsc-mobile)


The API server:

- Provides an API interface for the app
- Imports user gig-activities and profile data from Argyle
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
* [Argyle](https://argyle.com)
* [Mixpanel](https://mixpanel.com/)
* [Sentry](https://sentry.io/welcome/)
* [OneSignal](https://onesignal.com/)


## Getting Started
* [Setting-up a Development Environment](/docs/developer_setup/README.md)
* [Environment Variables](/docs/environment_variables/README.md)
* [Populating Geosptial Referece Data](/docs/populating_geographies/README.md)


## Deployment
* Code is hosted on GitHub
* The deployment is from Google Cloud
* There is a staging and a production environemnt
* Databases are in Google Cloud SQL

### CI / CD pipeline
* New commits to main will trigger new builds via Cloud Build
* Builds in Cloud Build will deploy to Cloud Run
* `main` corresponds to the production deployment. Merges to `main` will auto-build to production.
* `staging` corresponds to the staging deployment. Merges to `staging` will auto-build to staging.

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
