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
    attrs_with_user = Map.put(attrs, "user_id", user_id)

    %CrepeEvent{}
    |> CrepeEvent.changeset(attrs_with_user)
    |> Repo.insert()
  end
end
