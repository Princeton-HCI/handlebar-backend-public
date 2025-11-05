defmodule DriversSeatCoop.Crepe.Collector do
  use Ecto.Schema
  import Ecto.Changeset
  alias DriversSeatCoop.Crepe.DataField

  @required_fields ~w(
    app_name
    app_package
  )a

  @optional_fields ~w(description)a

  schema "crepe_collector" do
    field :app_name, :string
    field :app_package, :string
    field :description, :string

    has_many :data_fields, DataField, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(collector, attrs) do
    collector
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> cast_assoc(:data_fields, required: true)
  end
end
