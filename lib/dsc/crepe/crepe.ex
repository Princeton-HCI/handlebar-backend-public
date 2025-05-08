defmodule DriversSeatCoop.Crepe do
  import Ecto.Query, warn: false
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Crepe.{Collector, DataField}

  def list_collectors do
    Repo.all(Collector)
    |> Repo.preload(:data_fields)
  end

  def get_collector!(id) do
    Repo.get!(Collector, id)
    |> Repo.preload(:data_fields)
  end

  def create_collector(attrs \\ %{}) do
    %Collector{}
    |> Collector.changeset(attrs)
    |> Repo.insert()
  end

  def update_collector(%Collector{} = collector, attrs) do
    collector
    |> Collector.changeset(attrs)
    |> Repo.update()
  end

  def delete_collector(%Collector{} = collector) do
    Repo.delete(collector)
  end

  def create_data_field(attrs \\ %{}) do
    %DataField{}
    |> DataField.changeset(attrs)
    |> Repo.insert()
  end
end
