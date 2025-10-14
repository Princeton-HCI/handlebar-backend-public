defmodule DriversSeatCoop.GigAccounts do
  @moduledoc """
  The GigAccounts context.
  """

  import Ecto.Query, warn: false
  alias DriversSeatCoop.GigAccounts.UserGigAccount

  def query do
    from(u in UserGigAccount)
  end

  def query_filter_user(query, user_id) do
    from(u in query, where: u.user_id == ^user_id)
  end

  def query_filter_is_connected(query) do
    from(u in query, where: u.is_connected == true)
  end
end
