defmodule DriversSeatCoop.Research.ResearchGroup do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields ~w(description name code)a
  @optional_fields ~w()a

  schema "research_groups" do
    field :description, :string
    field :name, :string
    field :code, :string

    timestamps()
  end

  @doc false
  def changeset(research_group, attrs) do
    research_group
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:code, name: :research_groups_code_lower_index)
  end
end
