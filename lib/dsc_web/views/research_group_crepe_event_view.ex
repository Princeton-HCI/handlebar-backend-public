defmodule DriversSeatCoopWeb.ResearchGroupCrepeEventView do
  use DriversSeatCoopWeb, :view

  def render("index.json", %{crepe_events: events}) do
    %{data: render_many(events, __MODULE__, "crepe_event.json", as: :crepe_event)}
  end

  def render("crepe_event.json", %{crepe_event: event}) do
    %{
      id: event.id,
      type: "crepe_event",

      content: event.content,
      collected_at: event.collected_at,
      inserted_at: event.inserted_at,

      user: render_user(event.user),
      data_field: render_data_field(event.data_field),
      membership: render_membership(event.membership)
    }
  end

  defp render_user(nil), do: nil
  defp render_user(user) do
    %{
      id: user.id,
      type: "user",
      first_name: user.first_name,
      last_name: user.last_name
    }
  end

  defp render_data_field(nil), do: nil
  defp render_data_field(df) do
    %{
      id: df.id,
      type: "data_field",
      name: df.name,
    }
  end

  defp render_membership(nil), do: nil
  defp render_membership(m) do
    %{
      id: m.id,
      type: "research_group_membership",
      role: m.role,
      research_group_id: m.research_group_id
    }
  end
end
