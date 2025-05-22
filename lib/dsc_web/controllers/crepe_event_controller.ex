defmodule DriversSeatCoopWeb.CrepeEventController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Crepe

  plug DriversSeatCoopWeb.AuthenticationPlug
  action_fallback DriversSeatCoopWeb.FallbackController

  def create(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.CrepeEventValidator.create(params),
         {:ok, %{crepe_event: _crepe_event, notification: notification}} <-
           Crepe.create_crepe_event(params, conn.assigns.user.id) do
      conn
      |> put_status(:created)
      |> render("success.json", notification: notification)
    end
  end
end
