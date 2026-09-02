defmodule DriversSeatCoopWeb.ResearchGroupCollectorView do
  use DriversSeatCoopWeb, :view

  def render("index.json", %{collectors: collectors_data}) do
    %{
      data:
        Enum.map(collectors_data, fn {collector, membership_id, group_name} ->
          collector_json =
            render_one(collector, __MODULE__, "collector.json", as: :collector)
          [collector_json, membership_id, group_name]
        end)
    }
  end

  def render("show.json", %{collector: collector}) do
    %{data: render_one(collector, __MODULE__, "collector.json", as: :collector)}
  end

  def render("collectors_index.json", %{collectors: collectors}) do
    %{data: render_many(collectors, __MODULE__, "collector.json", as: :collector)}
  end

  def render("collector.json", %{collector: c}) do
    %{
      collector_id: c.id,
      app_name: c.app_name,
      app_package: c.app_package,
      description: c.description,
      collection_interval_seconds: c.collection_interval_seconds,
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
