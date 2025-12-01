defmodule DriversSeatCoopWeb.ResearchGroupView do
  use DriversSeatCoopWeb, :view
  alias DriversSeatCoopWeb.ResearchGroupView

  def render("index.json", %{research_groups: research_groups}) do
    %{data: render_many(research_groups, ResearchGroupView, "group_with_role.json", as: :research_group)}
  end

  def render("show.json", %{research_group: research_group}) do
    %{data: render_one(research_group, ResearchGroupView, "research_group.json", as: :research_group)}
  end

  def render("create.json", %{research_group: research_group}) do
    %{data: render_one(research_group, ResearchGroupView, "group_with_role.json", as: :research_group)}
  end

  def render("group_with_role.json", %{research_group: %{group: group, role: role}}) do
    %{
      id: group.id,
      description: group.description,
      name: group.name,
      code: group.code,
      role: role
    }
  end

  def render("research_group.json", %{research_group: group}) do
    %{
      id: group.id,
      description: group.description,
      name: group.name,
      code: group.code
    }
  end

end
