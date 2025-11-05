defmodule DriversSeatCoopWeb.ResearchGroupController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroup

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/groups
  def index(conn, _params) do
    user_id = conn.assigns.user.id
    groups = Research.list_user_research_groups(user_id)
    render(conn, DriversSeatCoopWeb.ResearchGroupView, "index.json", research_groups: groups)
  end

  # GET /api/research/groups/:id
  def show(conn, %{"id" => id}) do
    case Research.get_research_group(String.to_integer(id)) do
      nil ->
        {:error, :not_found}

      %ResearchGroup{} = rg ->
        render(conn, DriversSeatCoopWeb.ResearchGroupView, "show.json", research_group: rg)
    end
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
    user_id = conn.assigns.user.id
    attrs = Map.put(attrs, "user_id", user_id)

    case Research.create_research_group(attrs) do
      {:ok, %ResearchGroup{} = rg} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.research_group_path(conn, :show, rg))
        |> render(DriversSeatCoopWeb.ResearchGroupView, "show.json", research_group: rg)

      {:error, changeset} -> {:error, changeset}
    end
  end

  # PATCH /api/research/groups/:id
  def update(conn, %{"id" => id, "research_group" => attrs}) do
    case Research.get_research_group(String.to_integer(id)) do
      nil ->
        {:error, :not_found}

      %ResearchGroup{} = rg ->
        case Research.update_research_group(rg, attrs) do
          {:ok, %ResearchGroup{} = rg} ->
            render(conn, DriversSeatCoopWeb.ResearchGroupView, "show.json", research_group: rg)

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  # DELETE /api/research/groups/:id
  def delete(conn, %{"id" => id}) do
    case Research.get_research_group(String.to_integer(id)) do
      nil ->
        {:error, :not_found}

      %ResearchGroup{} = rg ->
        case Research.delete_research_group(rg) do
          {:ok, _} -> send_resp(conn, 204, "")
          {:error, changeset} -> {:error, changeset}
        end
    end
  end
end
