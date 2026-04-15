defmodule DriversSeatCoopWeb.ResearchGroupLlmView do
  use DriversSeatCoopWeb, :view

  def render("batch_selection.json", %{results: results}) do
    %{
      results:
        Map.new(results, fn {entity_id, result} ->
          {
            to_string(entity_id),
            %{
              best_index: result.best_index,
              descriptions: result.descriptions
            }
          }
        end)
    }
  end
end
