defmodule DriversSeatCoopWeb.ResearchGroupCollectorController do
  use DriversSeatCoopWeb, :controller
  alias DriversSeatCoop.Research

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/groups/:group_id/collectors
  def index_group(conn, %{"group_id" => gid}) do
    group_id = String.to_integer(gid)
    collectors = Research.list_group_collectors(group_id)
    render(conn, "collectors_index.json", collectors: collectors)
  end

  # GET /api/research/me/collectors
  def index_participant(conn, _params) do
    user_id = conn.assigns.user.id
    collectors = DriversSeatCoop.Research.list_participant_collectors(user_id)
    render(conn, "index.json", collectors: collectors)
  end

  # POST /api/research/groups/:group_id/collectors
  # body: { "collector": { ... } }
  def create(conn, %{"group_id" => gid, "collector" => collector_params}) do
    group_id = String.to_integer(gid)

    case Research.create_collector_and_attach(group_id, collector_params) do
      {:ok, collector} ->
        # return newly created collector
        conn
        |> put_status(:created)
        |> render(DriversSeatCoopWeb.ResearchGroupCollectorView, "show.json",
          collector: collector
        )

      {:error, _step, changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  # PATCH /api/research/groups/:group_id/collectors/:collector_id
  # body: { "collector": { "description": ..., "collection_interval_seconds": ... } }
  # Partial update: only the keys present in the body are applied.
  def update(conn, %{"group_id" => gid, "collector_id" => cid, "collector" => collector_params}) do
    group_id = String.to_integer(gid)
    collector_id = String.to_integer(cid)

    case Research.get_group_collector(group_id, collector_id) do
      nil ->
        {:error, :not_found}

      collector ->
        with {:ok, collector} <- Research.update_collector(collector, collector_params) do
          render(conn, "show.json", collector: collector)
        end
    end
  end

  # DELETE /api/research/groups/:group_id/collectors/:collector_id
  def delete(conn, %{"group_id" => gid, "collector_id" => cid}) do
    group_id = String.to_integer(gid)
    collector_id = String.to_integer(cid)

    case Research.get_research_group_collector(group_id, collector_id) do
      nil ->
        {:error, :not_found}

      rgc ->
        case Research.delete_research_group_collector(rgc) do
          {:ok, _} ->
            send_resp(conn, 204, "")

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end
end
