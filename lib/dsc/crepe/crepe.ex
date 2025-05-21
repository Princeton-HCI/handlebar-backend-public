defmodule DriversSeatCoop.Crepe do
  @moduledoc """
  The Crepe context.
  """
  import Ecto.Query, warn: false
  alias DriversSeatCoop.Crepe.CrepeEvent
  alias DriversSeatCoop.Crepe.Collector
  alias DriversSeatCoop.Repo

  @doc """
  Lists all collectors.
  """
  def list_collectors do
    Repo.all(Collector)
    |> Repo.preload(:data_fields)
  end

  @doc """
  Creates a crepe_event.
  """
  def create_crepe_event(attrs, user_id) do
    # TODO: Define notification behavior here based on user and/or data field
    notification = nil

    with {:ok, crepe_event} <-
      %CrepeEvent{user_id: user_id}
      |> CrepeEvent.changeset(attrs)
      |> Repo.insert() do
      {:ok, %{crepe_event: crepe_event, notification: notification}}
    end
  end
end
