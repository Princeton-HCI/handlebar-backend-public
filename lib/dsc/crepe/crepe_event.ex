defmodule DriversSeatCoop.Crepe.CrepeEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields ~w(user_id data_field_id collected_at content)a
  @optional_fields ~w()a

  schema "crepe_event" do
    field :user_id, :integer
    field :data_field_id, :string
    field :collected_at, :utc_datetime
    field :content, :string

    timestamps()
  end

  def changeset(crepe_event, attrs) do
    crepe_event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
