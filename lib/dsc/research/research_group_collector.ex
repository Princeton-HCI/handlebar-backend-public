defmodule DriversSeatCoop.Research.ResearchGroupCollector do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields ~w(research_group_id collector_id added_at)a
  @optional_fields ~w()a

  schema "research_group_collectors" do
    belongs_to :research_group, DriversSeatCoop.Research.ResearchGroup
    belongs_to :collector, DriversSeatCoop.Crepe.Collector

    timestamps(updated_at: false, inserted_at: :added_at)
  end

  def changeset(rgc, attrs) do
    rgc
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:research_group)
    |> assoc_constraint(:collector)
    |> unique_constraint([:research_group_id, :collector_id], name: :rgc_unique_ids)
  end
end
