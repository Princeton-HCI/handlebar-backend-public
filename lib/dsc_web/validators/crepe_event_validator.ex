defmodule DriversSeatCoopWeb.CrepeEventValidator do
  alias Ecto.Changeset

  def create(params) do
    types = %{
      collected_at: :utc_datetime,
      content: :string
    }

    data = %{}

    {data, types}
    |> Changeset.cast(params, Map.keys(types))
    |> Changeset.validate_required([:collected_at, :content])
    |> Changeset.apply_action(:insert)
  end
end
