defmodule DriversSeatCoop.Crepe.Collector do
  use Ecto.Schema
  import Ecto.Changeset
  alias DriversSeatCoop.Crepe.DataField

  @required_fields ~w(
    app_name
    app_package
    description
  )a

  @optional_fields ~w(collection_interval_seconds)a

  # Fields a researcher may change after the collector has been created.
  @updatable_fields ~w(description collection_interval_seconds)a

  schema "crepe_collector" do
    field :app_name, :string
    field :app_package, :string
    field :description, :string

    # Seconds between captures. nil or 0 both mean "collect every time it
    # matches"; the debounce itself is enforced on-device.
    field :collection_interval_seconds, :integer

    has_many :data_fields, DataField, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(collector, attrs) do
    collector
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_collection_interval_seconds()
    |> cast_assoc(:data_fields, required: true)
  end

  @doc """
  Changeset for a partial update: only the keys present in `attrs` are
  applied, and data fields are left alone.
  """
  def update_changeset(collector, attrs) do
    collector
    # empty_values: [] so an explicit "" description becomes a change and
    # gets rejected below, rather than being silently dropped by cast.
    |> cast(attrs, @updatable_fields, empty_values: [])
    |> maybe_validate_description(attrs)
    |> validate_collection_interval_seconds()
  end

  defp maybe_validate_description(changeset, attrs) do
    if Map.has_key?(attrs, "description") or Map.has_key?(attrs, :description) do
      validate_required(changeset, [:description])
    else
      changeset
    end
  end

  defp validate_collection_interval_seconds(changeset) do
    validate_number(changeset, :collection_interval_seconds, greater_than_or_equal_to: 0)
  end
end
