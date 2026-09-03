defmodule DriversSeatCoopWeb.ResearchGroupSensorView do
  use DriversSeatCoopWeb, :view

  # Participant view. Matches the positional-array shape of
  # ResearchGroupCollectorView's "index.json" so the device parses both the
  # same way: [sensor, membership_id, group_name].
  def render("index.json", %{sensor_configs: sensor_configs_data}) do
    %{
      data:
        Enum.map(sensor_configs_data, fn {sensor_config, membership_id, group_name} ->
          sensor_json = render_one(sensor_config, __MODULE__, "sensor.json", as: :sensor)
          [sensor_json, membership_id, group_name]
        end)
    }
  end

  def render("show.json", %{sensor_config: sensor_config}) do
    %{data: render_one(sensor_config, __MODULE__, "sensor.json", as: :sensor)}
  end

  def render("sensors_index.json", %{sensor_configs: sensor_configs}) do
    %{data: render_many(sensor_configs, __MODULE__, "sensor.json", as: :sensor)}
  end

  def render("sensor.json", %{sensor: s}) do
    %{
      sensor_id: s.id,
      type: s.type,
      enabled: s.enabled,
      sample_interval_seconds: s.sample_interval_seconds,
      trigger_type: s.trigger_type,
      trigger_app_package: s.trigger_app_package,
      trigger_collector_id: s.trigger_collector_id,
      timeout_seconds: s.timeout_seconds
    }
  end
end
