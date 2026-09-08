defmodule DriversSeatCoopWeb.PointView do
  use DriversSeatCoopWeb, :view

  def render("index.json", %{points: points, meta: meta}) do
    %{
      data: render_many(points, __MODULE__, "point.json", as: :point),
      meta: %{
        after: meta.after,
        before: meta.before,
        limit: meta.limit,
        total_count: meta.total_count
      }
    }
  end

  def render("point.json", %{point: point}) do
    {latitude, longitude} = coordinates(point.geometry)

    %{
      id: point.id,
      # Mirrors the "type" discriminator on crepe_event.json so a client can
      # render a mixed timeline of screen and location data.
      type: "location_point",
      latitude: latitude,
      longitude: longitude,
      accuracy: point.accuracy,
      altitude: point.altitude,
      speed: point.speed,
      heading: point.heading,
      is_moving: point.is_moving,
      activity_type: point.activity_type,
      battery_level: point.battery_level,
      status: point.status,
      recorded_at: point.recorded_at,
      inserted_at: point.inserted_at,
      membership_id: point.membership_id,
      user_id: point.user_id
    }
  end

  # latitude/longitude are virtual on the schema; the persisted value is a
  # PostGIS geometry, which loads as a Geo.Point with {lon, lat} coordinates.
  defp coordinates(%Geo.Point{coordinates: {lon, lat}}), do: {lat, lon}
  defp coordinates(_), do: {nil, nil}
end
