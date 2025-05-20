defmodule DriversSeatCoopWeb.CrepeEventView do
  use DriversSeatCoopWeb, :view

  def render("success.json", %{notification: notification}) do
    %{
      success: true,
      notification: notification
    }
  end
end
