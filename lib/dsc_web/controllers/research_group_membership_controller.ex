defmodule DriversSeatCoopWeb.ResearchGroupMembershipController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroupMembership
  alias DriversSeatCoop.Research.ResearchGroup

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/groups/:group_id/members
  def index(conn, %{"group_id" => gid}) do
    group_id = String.to_integer(gid)
    memberships = Research.list_group_members(group_id)

    render(conn, DriversSeatCoopWeb.ResearchGroupMembershipView, "index.json",
      memberships: memberships
    )
  end

  # POST /api/research/groups/:group_id/members
  # body: { "email": "..." }
  def create_researcher(conn, %{"group_id" => gid, "email" => email}) do
    group_id = String.to_integer(gid)

    case Accounts.get_user_by_email(email) do
      nil ->
        {:error, :not_found}

      %Accounts.User{} = user ->
        case Research.get_user_membership_for_group(user.id, group_id) do
          %ResearchGroupMembership{} = _m ->
            {:error, :conflict}

          nil ->
            case Research.enroll_user(user.id, group_id, "researcher") do
              {:ok, _} ->
                send_resp(conn, 201, "")

              {:error, changeset} ->
                {:error, changeset}
            end
        end
    end
  end


  # POST /api/research/memberships/join
  # body: { "code": "ABC123" }
  def join(conn, %{"code" => code}) do
    user_id = conn.assigns.user.id

    case Research.get_research_group_by_case_insensitive_code(code) do
      nil ->
        {:error, :not_found}

      %ResearchGroup{} = rg ->
        case Research.get_user_membership_for_group(user_id, rg.id) do
          %ResearchGroupMembership{} ->
            # Already active
            send_resp(conn, 409, "")

          nil ->
            case Research.enroll_user(user_id, rg.id, "participant") do
              {:ok, _} ->
                send_resp(conn, 201, "")

              {:error, changeset} ->
                {:error, changeset}
            end
        end
    end
  end

  # PATCH /api/research/memberships/:membership_id
  # body: { attrs }
  def update(conn, %{"membership_id" => mid, "membership" => attrs}) do
    caller_id = conn.assigns.user.id
    membership_id = String.to_integer(mid)

    case Research.get_membership_by_id(membership_id) do
      nil ->
        {:error, :not_found}

      %ResearchGroupMembership{user_id: uid} = m ->
        if uid != caller_id do
          {:error, :unauthorized}
        else
          case Research.update_membership(m, attrs) do
            {:ok, updated} ->
              render(conn, DriversSeatCoopWeb.ResearchGroupMembershipView, "member.json",
                research_group_membership: updated
              )

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end


  # DELETE /api/research/memberships/:membership_id
  def leave(conn, %{"membership_id" => mid}) do
    caller_id = conn.assigns.user.id
    membership_id = String.to_integer(mid)

    case Research.get_membership_by_id(membership_id) do
      nil ->
        {:error, :not_found}

      # Researcher trying to leave
      %ResearchGroupMembership{
        user_id: uid,
        research_group_id: gid,
        role: "researcher"
      } = _m ->
        if uid != caller_id do
          {:error, :unauthorized}
        else
          if Research.only_active_researcher?(gid) do
            # Last active researcher, throw conflict
            {:error, :conflict}
          else
            case Research.unenroll_user(uid, gid) do
              {:ok, _} -> send_resp(conn, 204, "")
              {:error, changeset} -> {:error, changeset}
            end
          end
        end

      # Participant trying to leave
      %ResearchGroupMembership{user_id: uid, research_group_id: gid} ->
        if uid != caller_id do
          {:error, :unauthorized}
        else
          case Research.unenroll_user(uid, gid) do
            {:ok, _} -> send_resp(conn, 204, "")
            {:error, changeset} -> {:error, changeset}
          end
        end
    end
  end

  # DELETE /api/research/groups/:group_id/members/:membership_id
  def kick(conn, %{"group_id" => gid, "membership_id" => mid}) do
    group_id = String.to_integer(gid)
    membership_id = String.to_integer(mid)
    caller_id = conn.assigns.user.id

    case Research.get_membership_by_id(membership_id) do
      nil ->
        {:error, :not_found}

      %ResearchGroupMembership{research_group_id: ^group_id, user_id: uid} ->
        if uid == caller_id do
          # User attempted to kick themselves, throw conflict
          {:error, :conflict}
        else
          case Research.unenroll_user(uid, group_id) do
            {:ok, _} -> send_resp(conn, 204, "")
            {:error, changeset} -> {:error, changeset}
          end
        end

      %ResearchGroupMembership{} ->
        {:error, :not_found}
    end
  end

end
