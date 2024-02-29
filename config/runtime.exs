import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/dsc start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dsc, DriversSeatCoopWeb.Endpoint, server: true
end

if config_env() == :prod do
  config :dsc,
    one_signal_api_key: System.get_env("ONE_SIGNAL_API_KEY"),
    one_signal_app_id: System.get_env("ONE_SIGNAL_APP_ID")

  database_url =
    System.get_env("CLOUD_SQL_CONNECTION_ID") ||
      raise """
      environment variable CLOUD_SQL_CONNECTION_ID is missing.
      For example: project:region:service
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []
  db_pool_size = System.get_env("POOL_SIZE") || "10"

  config :dsc, DriversSeatCoop.Repo,
    # ssl: true,
    socket_dir: "/cloudsql/#{System.get_env("CLOUD_SQL_CONNECTION_ID")}",
    username: "postgres",
    password: System.get_env("DB_PASSWORD"),
    database: System.get_env("DB_NAME"),
    pool_size: String.to_integer("#{db_pool_size}"),
    timeout: 50_000,
    connect_timeout: 50_000,
    socket_options: maybe_ipv6,
    types: DriversSeatCoop.PostgresTypes



  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :dsc, DriversSeatCoopWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  terms_v1_id =
    case System.fetch_env("TERMS_V1_ID") do
      :error -> nil
      {:ok, id} -> String.to_integer(id)
    end

  config :dsc,
    terms_v1_id: terms_v1_id

  config :dsc, DriversSeatCoop.Argyle,
    client_id: System.get_env("ARGYLE_ID"),
    client_secret: System.get_env("ARGYLE_SECRET"),
    enable_background_tasks?: System.get_env("ARGYLE_ENABLE_BACKGROUND_TASKS") == "true",
    url: "https://api.argyle.com/v1/"

  config :dsc, DriversSeatCoop.B2,
    key_id: System.get_env("B2_KEY_ID"),
    application_key: System.get_env("B2_APPLICATION_KEY"),
    bucket: System.get_env("B2_BUCKET")

  config :dsc, DriversSeatCoopWeb.Mailer,
    adapter: Swoosh.Adapters.Sendgrid,
    api_key: System.get_env("SENDGRID_API_KEY"),
    from_name: System.get_env("EMAIL_FROM_NAME"),
    from_address: System.get_env("EMAIL_FROM_ADDRESS")

  config :dsc, DriversSeatCoop.Mixpanel,
    service_account_id: System.get_env("MIX_PANEL_ACCT_ID"),
    service_account_secret: System.get_env("MIX_PANEL_ACCT_SECRET"),
    project_id: System.get_env("MIX_PANEL_PROJECT_ID"),
    project_token: System.get_env("MIX_PANEL_PROJECT_TOKEN")

  config :dsc, DriversSeatCoop.Help, forward_to_csv: System.get_env("HELP_REQUEST_EMAIL_CSV")
end

config :dsc, DriversSeatCoopWeb.AppDowntimePlug,
  is_downtime?: System.get_env("MAINTENANCE_MODE_ENABLED") == "true",
  allow_admins?: System.get_env("MAINTENANCE_MODE_ALLOW_ADMINS") == "true",
  downtime_title: System.get_env("MAINTENANCE_MODE_TITLE"),
  downtime_message: System.get_env("MAINTENANCE_MODE_MESSAGE")

config :dsc, DriversSeatCoopWeb.OutOfDateAppVersionPlug,
  min_version: System.get_env("MOBILE_APP_MIN_VERSION"),
  store_url_ios: System.get_env("MOBILE_APP_STORE_URL_IOS"),
  store_url_android: System.get_env("MOBILE_APP_STORE_URL_ANDROID"),
  store_url_default: System.get_env("MOBILE_APP_STORE_URL_DEFAULT")
