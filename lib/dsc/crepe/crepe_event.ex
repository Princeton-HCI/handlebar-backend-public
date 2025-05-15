defmodule DriversSeatCoop.Crepe.CrepeEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias DriversSeatCoop.Accounts.User

  @required_fields ~w(user_id data_field_id collected_at content)a
  @optional_fields ~w()a

  schema "crepe_event" do
    field :data_field_id, :string
    field :collected_at, :utc_datetime
    field :content, :string

    belongs_to :user, User

    timestamps()
  end

  def changeset(crepe_event, attrs) do
    crepe_event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:user)
  end
end
