# Envrionment Variables

## General Settings

- `SECRET_KEY_BASE`
  Used for encyrpting authentication tokens allowing the mobile device to authenticate with the API.
  <br/>

- `TERMS_V1_ID`
  points to an initial terms of service that all users have accepted. Ususally `1`, but check the database for the first identifier supplied when running seed data.

## Web Settings

- `HOST`
  Defines the externally visble URL for the API service. Marketing service (Calls to Action and Surveys) rely on this value when presenting static content (like images) to the users as part of a campaign.

## Database Settings

- `DATABASE_URL`
  A URL that can be used to connect to the Postgres database. usually in the form , `postgres://{user_id}:{password}@{host}:{port}/{database_name}`
  <br/>
- `POOL_SIZE`
  The number of simultaneous connections to the database allowed by the api server.

## Minimum App Version

Comparing app requests' HTTP header value `dsc-app-version` to a minimum allowable app version. If the caller is below the threshold, server responds with an HTTP-426 message with further information. [(see plug)](../../lib/dsc_web/plugs/out_of_date_app_version_plug.ex)

- `MOBILE_APP_MIN_VERSION`
  The minimum version allowed. If not set, no checking occurs and the other settings are not used. Example: `4.0.1`
  <br/>
- `MOBILE_APP_STORE_URL_IOS`
  The URL to the app store for ios. Example: `https://apps.apple.com/us/app/drivers-seat/id1486642582?ls=1`
  <br/>
- `MOBILE_APP_STORE_URL_ANDROID`
  The URL to the app store for Android. Example: `https://play.google.com/store/apps/details?id=com.rkkn.driversseatcoop2`
  <br/>
- `MOBILE_APP_STORE_URL_DEFAULT`
  If the calling platform cannot be determined (from HTTP Header `dsc-device-platform`) to be either ios or android, the default URL to return to the caller. Recommend setting this to your organization's web site or something generic. Example: `https://www.driversseat.co`

## Downtime/Maintenance Windows

Allows admins to manage downtimes. [(see plug)](../../lib/dsc_web/plugs/app_downtime_plug.ex)

- `MAINTENANCE_MODE_ENABLED`
  Set to `true` to enable a downtime. During downtimes, API requests receive HTTP-503 messages.
  <br/>
- `MAINTENANCE_MODE_ALLOW_ADMINS`
  During a downtime, When this value is set to `true`, users with role=`admin` will be able to log into the system and bypass the downtime. Useful for testing migrations or deployments.
  <br/>
- `MAINTENANCE_MODE_TITLE`
  Title text to display to users for the downtime. The mobile app will display this title.
  <br/>
- `MAINTENANCE_MODE_MESSAGE`
  Description text to display for the downtime. The mobile app witll display the description.

## Transient File storage

When users request exports of their data, the file is prepared and uploaded to Backblaze. An email is sent to the requesting user providing them an expiring link that they can use to download the file.

- `B2_APPLICATION_KEY`
- `B2_BUCKET`
- `B2_KEY_ID`

## Email settings

Sendgrid is used to send emails from the API server for (1) Password Resets; (2) Export File links; (3) Help Requests.

- `SENDGRID_API_KEY`
- `SENDGRID_USERNAME`
- `SENDGRID_PASSWORD`
- `EMAIL_FROM_ADDRESS`
  The email address placed in the From field of the email.
- `EMAIL_FROM_NAME`
  The display name of the sender of the email.

## User Help Requests

- `HELP_REQUEST_EMAIL_CSV`
  When users put in a help request in the mobile app, it is forwarded to an API endpoint. An email is generated and sent this address with the users's request.

## Event Tracking (Mixpanel)

Mixpanel is heavily used by the mobile app to track user activity. The API server facilitates analysis by placing users into various populations. For example, the API server places users into metro area populations so that they may be used for reporting. Additionally, when a user has requested their information to be deleted, the API server is responsible for de-identifying the information (keeping the history).

- `MIX_PANEL_ACCT_ID`
- `MIX_PANEL_ACCT_SECRET`
- `MIX_PANEL_PROJECT_TOKEN`

## Push Notifications (OneSignal)

The API server sends push notifications to users using the OneSignal API.

- `ONE_SIGNAL_API_KEY`
- `ONE_SIGNAL_APP_ID`

## Log Forwarding (Papertrail)

Papertail is a service offered by Heroku for log analysis.

- `PAPERTRAIL_API_TOKEN`

## Error Reporting (Sentry)

Sentry is a service that captures and reports unexpected error conditions.

- `SENTRY_DSN`
- `RELEASE_LEVEL`
  The release level is used to distinguish the environment from which errors are being reported. Any values other `production` and `staging` are not sent to sentry. If not set as an environment variable `development` is used.
