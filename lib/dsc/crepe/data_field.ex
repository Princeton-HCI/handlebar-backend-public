defmodule DriversSeatCoop.Crepe.DataField do
  use Ecto.Schema
  import Ecto.Changeset
  alias DriversSeatCoop.Crepe.Collector

  @required_fields ~w(
    graph_query
    name
    collector_id
  )a

  @optional_fields ~w()a

  schema "crepe_data_field" do
    field :graph_query, :string
    field :name, :string

    belongs_to :collector, Collector

    timestamps()
  end

  @doc false
  def changeset(data_field, attrs) do
    data_field
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:collector_id)
  end
end
