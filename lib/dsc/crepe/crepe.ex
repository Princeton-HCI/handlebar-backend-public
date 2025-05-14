defmodule DriversSeatCoop.Crepe do
  import Ecto.Query, warn: false
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Crepe.Collector

  def list_collectors do
    Repo.all(Collector)
    |> Repo.preload(:data_fields)
  end
end
