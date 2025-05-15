defmodule DriversSeatCoop.Crepe do
  @moduledoc """
  The Crepe context.
  """
  import Ecto.Query, warn: false
  alias DriversSeatCoop.Crepe.CrepeEvent
  alias DriversSeatCoop.Repo

  @doc """
  Creates a crepe_event.
  """
  def create_crepe_event(attrs, user_id) do
    %CrepeEvent{user_id: user_id}
    |> CrepeEvent.changeset(attrs)
    |> Repo.insert()
  end
end
