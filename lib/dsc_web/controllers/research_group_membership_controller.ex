defmodule DriversSeatCoopWeb.ResearchGroupMembershipController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Research

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/groups/:group_id/members
  def index(conn, _params) do
    memberships = Research.list_group_members(conn.assigns.research_group_id)
    render(conn, "index.json", memberships: memberships)
  end

  # GET /api/research/groups/:group_id/researchers
  def index_researchers(conn, _params) do
    researchers = Research.list_group_researchers(conn.assigns.research_group_id)
    render(conn, "index.json", memberships: researchers)
  end

  # GET api/research/groups/:group_id/membership
  def show_mine(conn, _params) do
    membership = Research.get_membership_by_id(conn.assigns.membership_id)
    render(conn, "show.json", membership: membership)
  end

  # POST /api/research/groups/:group_id/members
  # body: { "email": "..." }
  def create_researcher(conn, %{"email" => email}) do
    group_id = conn.assigns.research_group_id
    case Accounts.get_user_by_email(email) do
      nil -> {:error, :not_found}
      user ->
        case Research.enroll_user(user.id, group_id, "researcher") do
          {:ok, membership} ->
            conn |> put_status(:created) |> render("member.json", research_group_membership: membership)
          {:error, _} -> {:error, :conflict}
        end
    end
  end

  # POST /api/research/memberships/join
  # body: { "code": "ABC123" }
  def join(conn, %{"code" => code}) do
    user_id = conn.assigns.user.id
    case Research.get_research_group_by_case_insensitive_code(code) do
      nil -> {:error, :not_found}
      rg ->
        case Research.get_user_membership_for_group(user_id, rg.id) do
          nil ->
            with {:ok, _} <- Research.enroll_user(user_id, rg.id, "participant"), do: send_resp(conn, 201, "")
          _ -> send_resp(conn, 409, "")
        end
    end
  end

  # PATCH /api/research/memberships/:membership_id
  # body: { attrs }
  def update(conn, %{"membership" => attrs}) do
    m = Research.get_membership_by_id(conn.assigns.membership_id)
    case Research.update_membership(m, attrs) do
      {:ok, updated} -> render(conn, "show.json", membership: updated)
      {:error, changeset} -> {:error, changeset}
    end
  end


  # DELETE /api/research/memberships/:membership_id
  def leave(conn, _params) do
    m = Research.get_membership_by_id(conn.assigns.membership_id)

    # Need to check if they are the last researcher
    if m.role == "researcher" && Research.only_active_researcher?(m.research_group_id) do
      {:error, :conflict}
    else
      with {:ok, _} <- Research.unenroll_user(m.user_id, m.research_group_id, String.to_atom(m.retention_pref_on_unenroll)) do
        send_resp(conn, 204, "")
      end
    end
  end

  # DELETE /api/research/groups/:group_id/members/:membership_id
  def kick(conn, %{"membership_id" => mid}) do
    membership_id = String.to_integer(mid)
    group_id = conn.assigns.research_group_id # The group the caller is allowed to manage

    case Research.get_membership_by_id(membership_id) do
      nil ->
        {:error, :not_found}

      m ->
        # PREVENT: Cross-group kicking
        if m.research_group_id != group_id do
          {:error, :not_found}
        else
          # Prevent kicking yourself
          if m.user_id == conn.assigns.user.id do
            {:error, :conflict}
          else
            with {:ok, _} <- Research.unenroll_user(m.user_id, m.research_group_id, String.to_atom(m.retention_pref_on_unenroll)) do
              send_resp(conn, 204, "")
            end
          end
        end
    end
  end
end
