defmodule DriversSeatCoopWeb.ResearchGroupCollectorView do
  use DriversSeatCoopWeb, :view
  alias DriversSeatCoopWeb.ResearchGroupCollectorView

  def render("index.json", %{collectors: collectors}) do
    %{data: render_many(collectors, ResearchGroupCollectorView, "collector.json", as: :collector)}
  end

  def render("collector.json", %{collector: c}) do
    %{
      collector_id: c.id,
      app_name: c.app_name,
      app_package: c.app_package,
      description: c.description,
      datafields: render_many(c.data_fields, __MODULE__, "data_field.json", as: :df)
    }
  end

  def render("data_field.json", %{df: df}) do
    %{
      data_field_id: df.id,
      graph_query: df.graph_query,
      name: df.name
    }
  end
end
