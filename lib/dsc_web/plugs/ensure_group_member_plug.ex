defmodule DriversSeatCoopWeb.EnsureGroupMemberPlug do
  @moduledoc """
  Ensures the user is an active member of the research group.
  Assigns both :research_group_id and :membership_id to the conn.
  Returns 404 if no active membership is found.
  """
  import Plug.Conn
  import Ecto.Query, only: [from: 2]

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research.ResearchGroupMembership

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns.user

    case fetch_membership_info(user.id, conn.params) do
      {:ok, group_id, membership_id} ->
        conn
        |> assign(:research_group_id, group_id)
        |> assign(:membership_id, membership_id)

      {:error, :not_found} ->
        conn |> send_resp(404, "") |> halt()
    end
  end

  # HIGHEST PRIORITY: The request has a group_id or id (e.g., /groups/:group_id/researchers)
  # We verify the caller is in the group, and find the CALLER'S membership_id.
  defp fetch_membership_info(user_id, %{"group_id" => gid}) do
    group_id = String.to_integer(gid)

    query = from m in ResearchGroupMembership,
      where: m.user_id == ^user_id and
             m.research_group_id == ^group_id and
             is_nil(m.unenrolled_at),
      select: m.id

    case Repo.one(query) do
      nil -> {:error, :not_found}
      membership_id -> {:ok, group_id, membership_id}
    end
  end

  # NEXT PRIORITY: The route uses standard :id (e.g., /groups/:id)
  defp fetch_membership_info(user_id, %{"id" => gid}) do
    fetch_membership_info(user_id, %{"group_id" => gid})
  end

  # LOWEST PRIORITY: The route ONLY has a membership_id (e.g., /memberships/:membership_id/...)
  # We verify the caller owns this membership, and find the group it belongs to.
  defp fetch_membership_info(user_id, %{"membership_id" => mid}) do
    membership_id = String.to_integer(mid)

    query = from m in ResearchGroupMembership,
      where: m.id == ^membership_id and
             m.user_id == ^user_id and
             is_nil(m.unenrolled_at),
      select: m.research_group_id

    case Repo.one(query) do
      nil -> {:error, :not_found}
      group_id -> {:ok, group_id, membership_id}
    end
  end

  # Catch-all
  defp fetch_membership_info(_user_id, _params), do: {:error, :not_found}
end
