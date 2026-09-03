defmodule DriversSeatCoopWeb.PointController do
  use DriversSeatCoopWeb, :controller
  require Logger
  alias DriversSeatCoop.Driving
  alias DriversSeatCoop.Research

  plug DriversSeatCoopWeb.AuthenticationPlug
  action_fallback DriversSeatCoopWeb.FallbackController

  @doc """
  This route is the route all points should go through coming from the app.
  The structure of the JSON received is controlled by the plugin the app uses,
  and differs slightly from our database structure, so we transform it
  within the controller into our own map.

  The Cordova plugin source code is here:
  https://github.com/transistorsoft/cordova-background-geolocation-lt
  The plugin docs on the structure submitted are here (under "HTTP Post Schema"):
  https://transistorsoft.github.io/cordova-background-geolocation-lt/interfaces/location.html

  The app includes "user_id" and "trip_id" under the "extras" key, but the "user_id" field
  is not used on our side. Instead, the currently authenticated user_id is passed to the Point
  creation function and used to create points.

  Handlebar additionally sends "membership_id" under "extras" to attribute the point
  to a study. It is verified against the caller's active memberships below; points
  claiming a membership the caller does not own are dropped rather than stored
  unattributed, so they cannot escape that study's retention policy.

  The app will send a bulk array of points, currently capped at 60 on the app's side.

  Points created are not rendered back in the response as they aren't used by the app.
  """
  def create(conn, %{"location" => points_params}) do
    points_params = List.wrap(points_params)
    coords_attributes = ["latitude", "longitude", "accuracy", "speed", "heading", "altitude"]

    device = Map.get(conn.assigns, :dsc_device)

    device_id =
      if is_nil(device) do
        nil
      else
        device.id
      end

    user_id = conn.assigns.user.id

    points_params =
      Enum.map(points_params, fn params ->
        with {:ok, coords} <- Map.fetch(params, "coords"),
             new_params <- Map.take(coords, coords_attributes),
             {:ok, extras} <- Map.fetch(params, "extras"),
             new_params <- Map.merge(extras, new_params),
             {:ok, timestamp} <- Map.fetch(params, "timestamp") do
          activity_type = get_in(params, ["activity", "type"])
          activity_confidence = get_in(params, ["activity", "confidence"])
          battery_level = get_in(params, ["battery", "level"])
          battery_is_charging = get_in(params, ["battery", "is_charging"])
          is_moving = Map.get(params, "is_moving")
          membership_id = normalize_membership_id(Map.get(new_params, "membership_id"))

          Map.put(new_params, "recorded_at", timestamp)
          |> Map.put("activity_type", activity_type)
          |> Map.put("activity_confidence", activity_confidence)
          |> Map.put("battery_level", battery_level)
          |> Map.put("battery_is_charging", battery_is_charging)
          |> Map.put("is_moving", is_moving)
          |> Map.put("membership_id", membership_id)
        else
          _ ->
            %{}
        end
      end)
      |> reject_unowned_memberships(user_id)

    case Driving.create_points(points_params, user_id, device_id) do
      {:ok, _points} ->
        nil

      {:error, changeset} ->
        Sentry.capture_message("failed to create many points",
          extra: %{changeset: inspect(changeset)}
        )
    end

    # ignore any failed points and return success (204)
    conn
    |> send_resp(:no_content, "")
  end

  # A body-supplied membership_id is never trusted on its own. Each distinct id
  # in the batch is checked once; points naming an unowned membership are
  # dropped, matching this endpoint's existing "silently skip bad points"
  # behaviour rather than failing the whole upload.
  defp reject_unowned_memberships(points_params, user_id) do
    claimed =
      points_params
      |> Enum.map(&Map.get(&1, "membership_id"))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    owned =
      claimed
      |> Enum.filter(fn membership_id ->
        match?({:ok, _}, Research.get_active_membership_for_user(user_id, membership_id))
      end)
      |> MapSet.new()

    Enum.reject(points_params, fn params ->
      membership_id = Map.get(params, "membership_id")

      if not is_nil(membership_id) and not MapSet.member?(owned, membership_id) do
        Logger.warn(
          "dropping point for membership_id #{inspect(membership_id)} not owned by user #{user_id}"
        )

        true
      else
        false
      end
    end)
  end

  defp normalize_membership_id(nil), do: nil
  defp normalize_membership_id(id) when is_integer(id), do: id

  defp normalize_membership_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_membership_id(_), do: nil
end
