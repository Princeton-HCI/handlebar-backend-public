defmodule DriversSeatCoopWeb.CrepeCollectorView do
  use DriversSeatCoopWeb, :view

  def render("index.json", %{collectors: collectors}) do
    %{data: render_many(collectors, __MODULE__, "collector.json", as: :collector)}
  end

  def render("collector.json", %{collector: collector}) do
    %{
      collectorId: collector.id,
      appName: collector.app_name,
      appPackage: collector.app_package,
      description: collector.description,
      datafields: render_many(collector.data_fields, __MODULE__, "data_field.json", as: :data_field)
    }
  end

  def render("data_field.json", %{data_field: data_field}) do
    %{
      datafieldId: data_field.id,
      graphQuery: data_field.graph_query,
      name: data_field.name
    }
  end
end
