defmodule DriversSeatCoopWeb.ResearchGroupController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroup
  alias DriversSeatCoop.Research.ResearchGroupMembership

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/groups
  def index(conn, _params) do
    user_id = conn.assigns.user.id
    groups = Research.list_user_research_groups(user_id)
    render(conn, "index.json", research_groups: groups)
  end

  # GET /api/research/groups/:id
  def show(conn, %{"id" => id}) do
    group_id = conn.assigns.research_group_id
    rg = Research.get_research_group(group_id)
    render(conn, "show.json", research_group: rg)
  end

  # GET /api/research/groups/lookup/:code
  def lookup(conn, %{"code" => code}) do
    case Research.get_research_group_by_case_insensitive_code(code) do
      %ResearchGroup{} = rg ->
        render(conn, "show.json", research_group: rg)
      _ ->
        {:error, :not_found}
    end
  end

  # POST /api/research/groups
  def create(conn, %{"research_group" => attrs}) do
    attrs = Map.put(attrs, "user_id", conn.assigns.user.id)

    case Research.create_research_group(attrs) do
      {:ok, rg} ->
        conn
        |> put_status(:created)
        |> render("create.json", research_group: %{group: rg, role: "researcher"})
      {:error, changeset} -> {:error, changeset}
    end
  end

  # PATCH /api/research/groups/:id
  def update(conn, %{"id" => id, "research_group" => attrs}) do
    rg = Research.get_research_group(conn.assigns.research_group_id)
    case Research.update_research_group(rg, attrs) do
      {:ok, rg} -> render(conn, "show.json", research_group: rg)
      {:error, changeset} -> {:error, changeset}
    end
  end

  # DELETE /api/research/groups/:id
  def delete(conn, %{"id" => id}) do
    rg = Research.get_research_group(conn.assigns.research_group_id)
    with {:ok, _} <- Research.delete_research_group(rg), do: send_resp(conn, 204, "")
  end
end
