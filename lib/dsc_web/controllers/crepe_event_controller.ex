defmodule DriversSeatCoopWeb.CrepeEventController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Crepe
  alias DriversSeatCoop.Crepe.CrepeEvent

  plug DriversSeatCoopWeb.AuthenticationPlug
  action_fallback DriversSeatCoopWeb.FallbackController

  def create(conn, %{"crepe_event" => crepe_event_params}) do
    notification = Map.get(crepe_event_params, "notification")

    crepe_event_params = Map.delete(crepe_event_params, "notification")

    with {:ok, params} <- DriversSeatCoopWeb.CrepeEventValidator.create(crepe_event_params),
         {:ok, %CrepeEvent{} = _crepe_event} <- Crepe.create_crepe_event(params, conn.assigns.user.id) do
      conn
      |> put_status(:created)
      |> render("success.json", notification: notification)
    end
  end
end
