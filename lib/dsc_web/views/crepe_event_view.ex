defmodule DriversSeatCoopWeb.CrepeEventView do
  use DriversSeatCoopWeb, :view

  def render("show.json", %{crepe_event: crepe_event, notification: notification}) do
    %{
      data_field_id: crepe_event.data_field_id,
      collected_at: crepe_event.collected_at,
      content: crepe_event.content,
      notification: notification
    }
  end
end
