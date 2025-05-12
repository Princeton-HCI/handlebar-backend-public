defmodule DriversSeatCoopWeb.CrepeCollectorController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Crepe
  alias DriversSeatCoop.Crepe.Collector

  action_fallback DriversSeatCoopWeb.FallbackController

  def index(conn, _params) do
    collectors = Crepe.list_collectors()
    render(conn, "index.json", collectors: collectors)
  end

  def show(conn, %{"id" => id}) do
    collector = Crepe.get_collector!(id)
    render(conn, "show.json", collector: collector)
  end
end
