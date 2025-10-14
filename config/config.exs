# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dsc,
  ecto_repos: [DriversSeatCoop.Repo],
  namespace: DriversSeatCoop

# Configures the endpoint
config :dsc, DriversSeatCoopWeb.Endpoint,
  http: [compress: true],
  pubsub_server: DriversSeatCoop.PubSub,
  render_errors: [view: DriversSeatCoopWeb.ErrorView, accepts: ~w(html json), layout: false],
  url: [host: "localhost"]

config :dsc, Oban,
  repo: DriversSeatCoop.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Every 15 minutes
       {"*/15 * * * *", DriversSeatCoop.ScheduledShifts.Oban.UpdateScheduledShiftReminders},
       # Every hour
       {"@hourly", DriversSeatCoop.Notifications.Oban.CheckForNewNotifications},
       # Every 10 minutes
       {"*/10 * * * *", DriversSeatCoop.Earnings.Oban.TriggerUpdateTimespansForOnShiftUsers},
       # The 11th and 21st of the month at 7am UTC
       {"0 7 11,21 * *", DriversSeatCoop.Notifications.Oban.GoalPerformanceUpdate,
        args: %{freq: "month"}},
       {"0 7 * * FRI", DriversSeatCoop.Notifications.Oban.GoalPerformanceUpdate,
        args: %{freq: "week"}},
       # Refresh marketing population membership
       {"0 */6 * * *", DriversSeatCoop.Marketing.Oban.UpdatePopulationMemberships},
       {"30 18 * * *", DriversSeatCoop.ExternalServices.Oban.RefreshExternalServiceIdentifiers,
        args: %{service: "mixpanel"}},
       {"45 18 * * *", DriversSeatCoop.Accounts.Oban.PurgeDeletedUsers}
     ]},
    # rescue orphaned jobs after 60 minutes
    Oban.Plugins.Lifeline,
    # keep old jobs for a week
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ],
  queues: [
    hubspot_api: 1,
    shift_reminders: 1,
    user_export_request: 1,
    update_timespans_for_user: 1,
    update_timespans_for_user_workday: 2,
    goals: 2,
    notifications: 2,
    marketing: 2,
    sync: 1,
    analytics: 2,
    purge: 1
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dsc, DriversSeatCoopWeb.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :torch,
  otp_app: :dsc,
  template_format: "eex"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("RELEASE_LEVEL") || "development",
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  included_environments: ~w(production staging)

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
