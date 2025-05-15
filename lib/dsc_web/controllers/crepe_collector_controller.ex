defmodule DriversSeatCoopWeb.CrepeCollectorController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Crepe

  action_fallback DriversSeatCoopWeb.FallbackController

  def index(conn, _params) do
    collectors = Crepe.list_collectors()
    render(conn, "index.json", %{collectors: collectors})
  end
end
