# dc notes from install

- no docker containers w hexpm on the right versions here.
- seems like erlang 25.3.2 might work since there's an appropriate image.
- installing that version on mac os M1 is a bit of a pain.

on mac os M1:

- for unixodbc:

```
brew install unixodbc
sudo ln -s $(realpath $(brew --prefix unixodbc)) /usr/local/odbc
```

- instal without `wx`:
```
KERL_CONFIGURE_OPTIONS="--without-wx --without-javac" asdf install erlang 25.3.2
```

some more info here:
https://devheroes.io/en/erlang-elixir-macos-m1/

# Developer Setup

1. **Clone this repo locally**
2. **Install Prerequisites**
   * [Homebrew](https://brew.sh/)
   * [NodeJS](https://nodejs.org/en/download/package-manager#alternatives-2)

      ```shell
      brew install node
      ```

   * [ASDF multiple runtime version manager](https://asdf-vm.com/)<br>
     Install ASDF and ensure that it starts up when opening new shell windows (zsh)

      ```shell
      brew install asdf
      echo -e '\n. /opt/homebrew/opt/asdf/libexec/asdf.sh' >> ~/.zshrc
      ```

   * PostgreSQL and PostGIS <br/>

      ```shell
      brew install postgresql
      brew install postgis
      ```

      ensure that you have a `postgres` user with password `postgres`
      <br/>

3. **Install Elixir and Erlang** <br/>
   Open a new shell, especially after installing Node and ASDF.

   ```shell
   asdf plugin add erlang
   asdf plugin add elixir
   asdf install erlang 25.3.2.7
   asdf install elixir 1.14.0-otp-25
   asdf global erlang 25.3.2.7
   asdf global elixir 1.14.0-otp-25
   ```

4. **Get Dependencies** <br/>
   Open a new shell.  You may be asked to confirm installation (select Y)

   ```shell
   mix deps.get
   ```

5. **Create empty API database and perform migrations**

   ```shell
   mix ecto.create
   mix ecto.migrate
   ```

6. **Seed Data** <br/>

    * Create the initial admin user and an initial terms of service.  You will need to do this prior to connecting with the mobile app as it requires users a terms of service to be available to the user.

      ```shell
      mix run priv/repo/seeds.exs
      ```

    * TODO: Loading Geographic shapes (region_county, region_state, region_metro_area, region_postal_code)
    <br/>

7. **Start the local Web Server** <br/>

   ```shell
   mix phx.server
   ```

   * API: http://localhost:4000
   * Admin Site: http://localhost:4000/_admin

## Running Unit Tests

Prior to running unit tests, you should have Postgresql installed and your postgres user configured.  Running the unit tests will create a test database `drivers_seat_coop_test`.

```shell
mix test
```


## Code Layout, Quality, Linting

The following will standardize code formatting an perform various code quality checks.  Ideally your CI/CD pipeline will verify that this has been done as part of pull request verification.

```shell
mix format
mix credo --strict --all
```

## Background/Scheduled Tasks (Oban)

   We use [Oban](https://hexdocs.pm/oban/Oban.html) to perform background tasks.

   In development, environment Variable `OBAN_QUEUES` will determines which queues will be active and how many workers will service each queue.  Since many background processes interact with external services, most times we do not want them to run.

   For example:

   ```shell
   export OBAN_QUEUES="update_timespans_for_user:1 update_timespans_for_user_workday:2 goals:2"
   ```

# Deploying on GCP

1. if you're using `conda`, install python 3.11 into your base environment using the below command or create a new env with python 3.11. if not using conda, the gcloud SDK install will install it for you. In the `base` env, run:
```
conda install -c conda-forge python=3.11
```
1. Install the [gcloud CLI](https://cloud.google.com/sdk/docs/install-sdk)
2. run gcloud auth: `gcloud auth login` and set up the project `gcloud config set project princeton-hci-wao-dsc`
3. make default application credentials: `gcloud auth application-default login`
1. Create a cloud SQL (postgres) server. Note the connection ID, should be in the form of 'project:region:instance'.
2. Download / install the [cloud SQL proxy client](https://cloud.google.com/sql/docs/postgres/connect-instance-auth-proxy#mac-m1)
3.  run the cloud proxy to connect to the remote db: `./sql-cloud-proxy princeton-hci-wao-dsc:us-central1:dsc-staging`

4. connect to the remote db and enable postgis. have your db password handy:

`psql postgres://postgres:<PASSWORD>@localhost:5432/drivers_seat_coop_staging`

```
postgres=> CREATE EXTENSION postgis;
```

5. run mix tasks for database from the dev container

Alter the dev container `devcontainer.json` to use `host.docker.internal` and the database you're making:

```
  "containerEnv": {
    "DATABASE_URL": "postgres://postgres:<PASSWORD>@host.docker.internal:5432/drivers_seat_coop_staging"
  }
```

In the dev container, run mix tasks:

```
mix ecto.create
```

```
mix ecto.migrate
```

```
mix run priv/repo/seeds.exs
```

Now your database should be ready to work with a production / staging deploy in google app engine.


6. To configure the DB url for the production container, you need to alter it to use a unix socket, like so:

```
postgres:///postgres:<PASSWORD>@drivers_seat_coop_staging?host=/cloudsql/princeton-hci-wao-dsc:us-central1:dsc-staging
```

On the container, the unix socket will be mounted at `/cloudsql`.

