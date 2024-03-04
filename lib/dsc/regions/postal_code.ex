defmodule DriversSeatCoop.Regions.PostalCode do
  use Ecto.Schema
  import Ecto.Changeset

  @sync_required_fields ~w(id postal_code geometry region_id_county region_id_state)a
  @sync_optional_fields ~w(region_id_metro_area)a

  @all_fields_except_geometry (@sync_required_fields ++ @sync_optional_fields) -- [:geometry]

  def get_non_geometry_fields, do: @all_fields_except_geometry

  schema "region_postal_code" do
    field :postal_code, :string
    field :geometry, Geo.PostGIS.Geometry
    belongs_to :metro_area, DriversSeatCoop.Regions.MetroArea, foreign_key: :region_id_metro_area
    belongs_to :county, DriversSeatCoop.Regions.County, foreign_key: :region_id_county
    belongs_to :state, DriversSeatCoop.Regions.State, foreign_key: :region_id_state
  end

  def sync_changeset(postal_code, attrs) do
    postal_code
    |> cast(attrs, @sync_required_fields ++ @sync_optional_fields)
    |> validate_required(@sync_required_fields)
    |> unique_constraint([:postal_code])
    |> assoc_constraint(:state)
    |> assoc_constraint(:county)
    |> assoc_constraint(:metro_area)
  end
end
