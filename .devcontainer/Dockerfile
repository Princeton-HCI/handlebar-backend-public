# Dockerfile
FROM hexpm/elixir:1.14.5-erlang-25.3.2.9-debian-buster-20240130

# Set environment variables
# ENV SECRET_KEY_BASE=your_secret_key_base \
#     TERMS_V1_ID=your_terms_v1_id \
#     HOST=your_host \
#     # DATABASE_URL="postgres://postgres:postgres@db:5432/drivers_seat_coop_dev"\
#     # DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/drivers_seat_coop_dev"\
#     POOL_SIZE=2
#     # MOBILE_APP_MIN_VERSION=your_mobile_app_min_version \
#     # MOBILE_APP_STORE_URL_IOS=your_mobile_app_store_url_ios \
#     # MOBILE_APP_STORE_URL_ANDROID=your_mobile_app_store_url_android \
#     # MOBILE_APP_STORE_URL_DEFAULT=your_mobile_app_store_url_default \
#     # MAINTENANCE_MODE_ENABLED=your_maintenance_mode_enabled \
# MAINTENANCE_MODE_ALLOW_ADMINS=your_maintenance_mode_allow_admins \
# MAINTENANCE_MODE_TITLE=your_maintenance_mode_title \
# MAINTENANCE_MODE_MESSAGE=your_maintenance_mode_message \
# B2_APPLICATION_KEY=your_b2_application_key \
# B2_BUCKET=your_b2_bucket \
# B2_KEY_ID=your_b2_key_id \
# SENDGRID_API_KEY=your_sendgrid_api_key \
# SENDGRID_USERNAME=your_sendgrid_username \
# SENDGRID_PASSWORD=your_sendgrid_password \
# EMAIL_FROM_ADDRESS=your_email_from_address \
# EMAIL_FROM_NAME=your_email_from_name \
# HELP_REQUEST_EMAIL_CSV=your_help_request_email_csv \
# MIX_PANEL_ACCT_ID=your_mix_panel_acct_id \
# MIX_PANEL_ACCT_SECRET=your_mix_panel_acct_secret \
# MIX_PANEL_PROJECT_TOKEN=your_mix_panel_project_token \
# ONE_SIGNAL_API_KEY=your_one_signal_api_key \
# ONE_SIGNAL_APP_ID=your_one_signal_app_id \
# PAPERTRAIL_API_TOKEN=your_papertrail_api_token \
# SENTRY_DSN=your_sentry_dsn \
# RELEASE_LEVEL=your_release_level \
# ARGYLE_ENABLE_BACKGROUND_TASKS=your_argyle_enable_background_tasks \
# ARGYLE_ID=your_argyle_id \
# ARGYLE_SECRET=your_argyle_secret



# RUN apk add --no-cache build-base npm git
# Install NodeJS and PostgreSQL
RUN apt-get update && apt-get install -y git curl gnupg lsb-release \
  postgresql-client build-essential inotify-tools --no-install-recommends
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install -y nodejs

# Set up ASDF
# RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.1
# ENV PATH="/root/.asdf/bin:/root/.asdf/shims:${PATH}"
# RUN asdf plugin add erlang
# RUN asdf plugin add elixir
# RUN asdf install erlang 25.3.2.7
# RUN asdf install elixir 1.14.0-otp-25
# RUN asdf global erlang 25.3.2.7
# RUN asdf global elixir 1.14.0-otp-25
# RUN asdf reshim

# Set up the application
WORKDIR /app
COPY . /app

# Set up the server
# CMD mix phx.server
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get

COPY .devcontainer/entrypoint.sh .

CMD ["bash", "./entrypoint.sh"]
