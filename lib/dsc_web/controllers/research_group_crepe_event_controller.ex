defmodule DriversSeatCoopWeb.ResearchGroupCrepeEventController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroupMembership

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/me/crepe-events
  # GET /api/research/me/crepe-events?group_id=...
  def index_participant(conn, params) do
    current_user = conn.assigns.user.id

    # Handle base filters (participant's own events from active memberships)
    base_filters = [user_id: current_user]

    # Add group_id if present in params
    filters =
      if group_id = params["group_id"] do
        # User asking for a specific group from their dashboard
        [group_id: group_id, active_membership: true] ++ base_filters
      else
        # User asking for all their data
        base_filters
      end

    events = Research.list_crepe_events(filters)
    render(conn, "index.json", crepe_events: events)
  end

  # GET /api/research/groups/:group_id/crepe-events
  def index_researcher_all_participants(conn, %{"group_id" => gid}) do
    group_id = String.to_integer(gid)

    # Fetch events for this group with the 'participant' role
    filters = [group_id: group_id, role: "participant"]
    events = Research.list_crepe_events(filters)
    render(conn, "index.json", crepe_events: events)
  end

  # GET /api/research/groups/:group_id/members/:membership_id/crepe-events
  def index_researcher_single_participant(conn, %{"group_id" => gid, "membership_id" => mid}) do
    group_id = String.to_integer(gid)
    membership_id = String.to_integer(mid)

    case Research.get_membership_by_id(membership_id) do
      nil ->
        {:error, :not_found}

      %ResearchGroupMembership{research_group_id: ^group_id} = _m ->
        events = Research.list_crepe_events([membership_id: membership_id])
        render(conn, "index.json", crepe_events: events)
      end
  end

  # POST /api/research/crepe-event
  def create(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.CrepeEventValidator.create(params),
         {:ok, %{crepe_event: _, notification: _notification}} <-
           Research.create_crepe_event(params, conn.assigns.user.id) do

        send_resp(conn, 201, "")
    end
  end


end
