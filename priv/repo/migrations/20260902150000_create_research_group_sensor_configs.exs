defmodule DriversSeatCoop.Repo.Migrations.CreateResearchGroupSensorConfigs do
  use Ecto.Migration

  def change do
    create table(:research_group_sensor_configs) do
      add :research_group_id,
          references(:research_groups, on_delete: :delete_all, type: :bigint),
          null: false

      # Sensor discriminator. Only "location" is supported today; the column
      # exists so that adding a sensor type needs no migration of this table.
      # Deliberately not constrained in the DB, unlike trigger_type below.
      add :type, :text, null: false

      add :enabled, :boolean, null: false, default: true

      # Seconds between samples while the sensor is actively collecting.
      # Unlike crepe_collector.collection_interval_seconds, 0 is meaningless
      # here, so this is required and must be positive.
      add :sample_interval_seconds, :integer, null: false

      # What turns collection on. "always" needs no target; "app_foreground"
      # uses trigger_app_package; "collector_match" uses trigger_collector_id.
      add :trigger_type, :text, null: false
      add :trigger_app_package, :text

      # nilify_all rather than restrict: deleting a collector should not fail
      # because a sensor references it. The config is left dormant and the
      # changeset requires the target to be re-set before it validates again.
      add :trigger_collector_id,
          references(:crepe_collector, on_delete: :nilify_all, type: :bigint)

      # Stop collecting this many seconds after the trigger was last satisfied.
      # NULL means "never stop once started". Enforcement lives on-device; the
      # backend only stores and serves the value.
      add :timeout_seconds, :integer

      timestamps()
    end

    # One config per sensor type per study, which makes create/update an upsert
    # from the client's point of view.
    create unique_index(:research_group_sensor_configs, [:research_group_id, :type],
             name: :rgsc_unique_group_type
           )

    create index(:research_group_sensor_configs, [:trigger_collector_id])

    create constraint(:research_group_sensor_configs, :rgsc_trigger_type_check,
             check: "trigger_type IN ('always', 'app_foreground', 'collector_match')"
           )

    create constraint(:research_group_sensor_configs, :rgsc_sample_interval_check,
             check: "sample_interval_seconds > 0"
           )

    create constraint(:research_group_sensor_configs, :rgsc_timeout_check,
             check: "timeout_seconds IS NULL OR timeout_seconds >= 0"
           )
  end
end
