defmodule DriversSeatCoopWeb.CrepeEventValidator do
  alias Ecto.Changeset

  def create(params) do
    types = %{
      data_field_id: :integer,
      membership_id: :integer,
      collected_at: :utc_datetime,
      content: :string
    }

    event_data = Map.get(params, "crepe_event", %{})

    data = %{}

    {data, types}
    |> Changeset.cast(event_data, Map.keys(types))
    |> Changeset.validate_required([:data_field_id, :membership_id, :collected_at, :content])
    |> Changeset.apply_action(:insert)
  end
end
