defmodule DriversSeatCoop.Research.SensorConfig do
  @moduledoc """
  Per-study configuration for a device sensor.

  A sensor is the non-screen counterpart to a `Crepe.Collector`: instead of
  querying the accessibility UI tree, it samples a device sensor on an interval
  while a trigger is satisfied. Only `"location"` exists today, but `type` is a
  discriminator so further sensors reuse this machinery.

  Triggering is a keepalive deadline rather than an on/off edge: the device
  refreshes a timestamp whenever the trigger is satisfied and stops sampling
  once `timeout_seconds` have passed without it. All of that is enforced
  on-device; the backend only stores and serves the configuration.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DriversSeatCoop.Crepe.Collector
  alias DriversSeatCoop.Research.ResearchGroup

  @valid_types ~w(location)
  @valid_trigger_types ~w(always app_foreground collector_match)

  # NOTE: research_group_id is omitted from these field sets and set explicitly
  # in Research.create_sensor_config/2, so a request body cannot retarget a
  # config at another study.
  @required_fields ~w(type sample_interval_seconds trigger_type)a
  @optional_fields ~w(enabled trigger_app_package trigger_collector_id timeout_seconds)a

  # A sensor's type is fixed at creation. Everything else is researcher-editable.
  @updatable_fields ~w(
    enabled
    sample_interval_seconds
    trigger_type
    trigger_app_package
    trigger_collector_id
    timeout_seconds
  )a

  schema "research_group_sensor_configs" do
    field :type, :string
    field :enabled, :boolean, default: true
    field :sample_interval_seconds, :integer
    field :trigger_type, :string
    field :trigger_app_package, :string
    field :timeout_seconds, :integer

    belongs_to :research_group, ResearchGroup
    belongs_to :trigger_collector, Collector, foreign_key: :trigger_collector_id

    timestamps()
  end

  @doc false
  def changeset(sensor_config, attrs) do
    sensor_config
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields ++ [:research_group_id])
    |> validate_inclusion(:type, @valid_types)
    |> common_validations()
    |> assoc_constraint(:research_group)
    |> unique_constraint([:research_group_id, :type], name: :rgsc_unique_group_type)
  end

  @doc """
  Changeset for a partial update: only the keys present in `attrs` are applied.
  `type` cannot be changed after creation.
  """
  def update_changeset(sensor_config, attrs) do
    sensor_config
    # empty_values: [] so an explicit "" trigger_app_package becomes a change
    # and gets rejected below, rather than being silently dropped by cast.
    |> cast(attrs, @updatable_fields, empty_values: [])
    |> common_validations()
    |> unique_constraint([:research_group_id, :type], name: :rgsc_unique_group_type)
  end

  defp common_validations(changeset) do
    changeset
    |> validate_inclusion(:trigger_type, @valid_trigger_types)
    |> validate_number(:sample_interval_seconds, greater_than: 0)
    |> validate_number(:timeout_seconds, greater_than_or_equal_to: 0)
    |> validate_trigger_target()
    |> normalize_timeout()
    |> foreign_key_constraint(:trigger_collector_id)
  end

  # always triggers never have timeouts
  defp normalize_timeout(changeset) do
    if get_field(changeset, :trigger_type) == "always" do
      put_change(changeset, :timeout_seconds, nil)
    else
      changeset
    end
  end

  # Validated against the merged state: get_field/2 falls back to the persisted
  # struct, so a PATCH that only changes the interval doesn't wrongly demand the
  # trigger target be resent.
  defp validate_trigger_target(changeset) do
    case get_field(changeset, :trigger_type) do
      "app_foreground" -> validate_required(changeset, [:trigger_app_package])
      "collector_match" -> validate_required(changeset, [:trigger_collector_id])
      _ -> changeset
    end
  end
end
