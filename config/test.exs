import Config

config :b2_client, :backend, B2Client.Backend.Memory

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dsc, DriversSeatCoop.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database:
    "#{System.get_env("POSTGRES_DB") || "drivers_seat_coop_test"}#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  types: DriversSeatCoop.PostgresTypes

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dsc, DriversSeatCoopWeb.Endpoint,
  url: [host: "localhost", port: 4002, scheme: "http"],
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EXDfhZmGqNuQTI6uTdSn3ThYUjNYR1vzV6UAXO6lwGQonrPpMOwTywo1HgzhRnXe",
  server: false

config :dsc, DriversSeatCoop.Help, forward_to_csv: "HELP_EMAIL_INBOX@TEST.COM"

config :dsc, Oban, queues: false, plugins: false

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warn

# Prevent password hashing from slowing down tests
config :argon2_elixir,
  t_cost: 1,
  m_cost: 8

config :dsc, DriversSeatCoop.B2,
  key_id: "valid_application_key_id",
  application_key: "valid_application_key",
  bucket: "ex-b2-client-test-bucket"

config :dsc, DriversSeatCoopWeb.Mailer,
  adapter: Swoosh.Adapters.Test,
  from_name: "DriversSeatCoop-Test",
  from_address: "support+test@example.com"

config :dsc, DriversSeatCoop.Mixpanel,
  service_account_id: "valid_mixpanel_account_id",
  service_account_secret: "valid_mixpanel_secret",
  project_id: "valid_mixpanel_project_id",
  project_token: "valid_mixpanel_token"

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
