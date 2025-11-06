defmodule DriversSeatCoopWeb.ResearchGroupView do
  use DriversSeatCoopWeb, :view
  alias DriversSeatCoopWeb.ResearchGroupView

  def render("index.json", %{research_groups: research_groups}) do
    %{data: render_many(research_groups, ResearchGroupView, "research_group.json")}
  end

  def render("show.json", %{research_group: research_group}) do
    %{data: render_one(research_group, ResearchGroupView, "research_group.json")}
  end

  def render("research_group.json", %{research_group: research_group}) do
    %{
      id: research_group.id,
      description: research_group.description,
      name: research_group.name,
      code: research_group.code
    }
  end
end
