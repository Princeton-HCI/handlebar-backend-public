defmodule DriversSeatCoopWeb.ResearchGroupLlmController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Research

  # POST /api/research/groups/:group_id/llm/query-selection
  #
  # Expected body:
  # {
  #   "user_description": "...",
  #   "entities": [
  #     %{
  #       "entity_id" => 123,
  #       "queries" => [
  #         %{"index" => 0, "query" => "..."},
  #         %{"index" => 1, "query" => "..."}
  #       ]
  #     }
  #   ]
  # }
  def select_queries(conn, %{
        "group_id" => gid,
        "user_description" => user_description,
        "entities" => entities
      }) do
    group_id = String.to_integer(gid)

    case Research.select_and_describe_queries_with_llm(
           group_id,
           user_description,
           entities
         ) do
      {:ok, results} ->
        render(conn, "batch_selection.json", results: results)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
