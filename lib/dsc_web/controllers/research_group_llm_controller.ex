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

      {:error, {:openai_request_failed, %Req.TransportError{reason: :timeout}}} ->
        conn
        |> put_status(:gateway_timeout)
        |> json(%{error: "OpenAI request timed out"})

      {:error, {:openai_http_error, status, body}} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{
          error: "OpenAI returned an error",
          upstream_status: status,
          details: body
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end
end
