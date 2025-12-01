defmodule DriversSeatCoop.Repo do
  use Ecto.Repo,
    otp_app: :dsc,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
