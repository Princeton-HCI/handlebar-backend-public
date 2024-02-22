# Drivers Seat Coop Web and API

Related Projects:

- [Mobile Application](https://github.com)


The API server:

- Provides an API interface for the app
- Imports user gig-activities and profile data from Argyle
- Host static content (for marketing campaigns and for help)

## Tech Stack

This project uses:

- [Heroku](https://heroku.com) for server and database hosting
- [PostgreSQL](https://www.postgresql.org/) as the back-end database
- [Elixir](https://elixir-lang.org) as the back-end language
- [Phoenix](https://www.phoenixframework.org) as the web framework
- [Oban](https://getoban.pro) for background job processing



## External Services
This project uses:
* [Backblaze (B2)](https://www.backblaze.com/)
* [Argyle](https://argyle.com)
* [Papertrail](https://www.papertrail.com/) via Heroku add-on
* [Mixpanel](https://mixpanel.com/)
* [SendGrid](https://sendgrid.com/en-us/solutions/email-api) via Heroku add-on
* [Sentry](https://sentry.io/welcome/)
* [OneSignal](https://onesignal.com/)


## Getting Started
* [Setting-up a Development Environment](/docs/developer_setup/README.md)
* [Environment Variables](/docs/environment_variables/README.md)
* [Populating Geosptial Referece Data](/docs/populating_geographies/README.md)