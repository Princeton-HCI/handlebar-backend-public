defmodule DriversSeatCoopWeb.CrepeEventController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Crepe
  alias DriversSeatCoop.Crepe.CrepeEvent

  plug DriversSeatCoopWeb.AuthenticationPlug
  action_fallback DriversSeatCoopWeb.FallbackController

  def create(conn, params) do
    notification = Map.get(params, "notification")
    params = Map.delete(params, "notification")

    with {:ok, params} <- DriversSeatCoopWeb.CrepeEventValidator.create(params),
         {:ok, %CrepeEvent{} = _crepe_event} <- Crepe.create_crepe_event(params, conn.assigns.user.id) do
      conn
      |> put_status(:created)
      |> render("success.json", notification: notification)
    end
  end
end
