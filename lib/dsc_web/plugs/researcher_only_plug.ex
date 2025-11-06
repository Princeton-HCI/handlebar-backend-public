# lib/dsc_web/plugs/require_researcher_for_group.ex
defmodule DriversSeatCoopWeb.ResearcherPlug do
  @moduledoc """
  This plug will check that conn.assigns.user is an active 'researcher'
  for the target research_group.
  """

  import Plug.Conn
  import Ecto.Query, only: [from: 2]

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research.ResearchGroupMembership

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns.user

    case resolve_group_id(conn) do
      {:ok, group_id} ->
        case researcher?(user.id, group_id) do
          true ->
            assign(conn, :research_group_id, group_id)

          false ->
            conn
            |> send_resp(403, "")
            |> halt()
        end

      {:error, :not_found} ->
        conn
        |> send_resp(404, "")
        |> halt()
    end
  end

  defp resolve_group_id(%{params: %{"group_id" => gid}}),
    do: {:ok, String.to_integer(gid)}

  defp resolve_group_id(%{params: %{"id" => gid}}),
    do: {:ok, String.to_integer(gid)}

  defp resolve_group_id(%{params: %{"membership_id" => mid}}) do
    membership_id = String.to_integer(mid)

    case Repo.get(ResearchGroupMembership, membership_id) do
      nil -> {:error, :not_found}
      %ResearchGroupMembership{research_group_id: gid} -> {:ok, gid}
    end
  end

  defp resolve_group_id(_), do: {:error, :not_found}

  defp researcher?(user_id, group_id) do
    from(m in ResearchGroupMembership,
      where:
        m.user_id == ^user_id and
        m.research_group_id == ^group_id and
        m.role == "researcher" and
        is_nil(m.unenrolled_at),
      select: 1,
      limit: 1
    )
    |> Repo.exists?()
  end
end
