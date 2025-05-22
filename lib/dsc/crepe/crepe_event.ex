defmodule DriversSeatCoop.Crepe.CrepeEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Crepe.DataField

  @required_fields ~w(user_id data_field_id collected_at content)a
  @optional_fields ~w()a

  schema "crepe_event" do
    field :collected_at, :utc_datetime
    field :content, :string

    belongs_to :user, User
    belongs_to :data_field, DataField

    timestamps()
  end

  def changeset(crepe_event, attrs) do
    crepe_event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:user)
    |> assoc_constraint(:data_field)
  end
end
