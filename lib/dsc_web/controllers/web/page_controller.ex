defmodule DriversSeatCoopWeb.Web.PageController do
  use DriversSeatCoopWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
