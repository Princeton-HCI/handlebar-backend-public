defmodule DriversSeatCoopWeb.ResearchGroupSensorController do
  use DriversSeatCoopWeb, :controller
  alias DriversSeatCoop.Research

  action_fallback DriversSeatCoopWeb.FallbackController

  # GET /api/research/groups/:group_id/sensors
  def index_group(conn, %{"group_id" => gid}) do
    group_id = String.to_integer(gid)
    sensor_configs = Research.list_group_sensor_configs(group_id)
    render(conn, "sensors_index.json", sensor_configs: sensor_configs)
  end

  # GET /api/research/me/sensors
  def index_participant(conn, _params) do
    user_id = conn.assigns.user.id
    sensor_configs = Research.list_participant_sensor_configs(user_id)
    render(conn, "index.json", sensor_configs: sensor_configs)
  end

  # POST /api/research/groups/:group_id/sensors
  # body: { "sensor": { "type": "location", "sample_interval_seconds": 30, ... } }
  def create(conn, %{"group_id" => gid, "sensor" => sensor_params}) do
    group_id = String.to_integer(gid)

    with {:ok, sensor_config} <- Research.create_sensor_config(group_id, sensor_params) do
      conn
      |> put_status(:created)
      |> render("show.json", sensor_config: sensor_config)
    end
  end

  # PATCH /api/research/groups/:group_id/sensors/:sensor_id
  # Partial update: only the keys present in the body are applied.
  def update(conn, %{"group_id" => gid, "sensor_id" => sid, "sensor" => sensor_params}) do
    group_id = String.to_integer(gid)
    sensor_id = String.to_integer(sid)

    case Research.get_group_sensor_config(group_id, sensor_id) do
      nil ->
        {:error, :not_found}

      sensor_config ->
        with {:ok, sensor_config} <- Research.update_sensor_config(sensor_config, sensor_params) do
          render(conn, "show.json", sensor_config: sensor_config)
        end
    end
  end

  # DELETE /api/research/groups/:group_id/sensors/:sensor_id
  def delete(conn, %{"group_id" => gid, "sensor_id" => sid}) do
    group_id = String.to_integer(gid)
    sensor_id = String.to_integer(sid)

    case Research.get_group_sensor_config(group_id, sensor_id) do
      nil ->
        {:error, :not_found}

      sensor_config ->
        case Research.delete_sensor_config(sensor_config) do
          {:ok, _} -> send_resp(conn, 204, "")
          {:error, changeset} -> {:error, changeset}
        end
    end
  end
end
