defmodule DriversSeatCoopWeb.PointControllerTest do
  use DriversSeatCoopWeb.ConnCase, async: true
  alias DriversSeatCoop.Devices
  alias DriversSeatCoop.Driving
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research.ResearchGroupMembership

  @create_attrs %{
    activity: %{confidence: 100, type: "still"},
    battery: %{is_charging: true, level: 0.91},
    coords: %{
      accuracy: 52,
      altitude: 22.1,
      altitude_accuracy: 107.7,
      heading: 0.35,
      heading_accuracy: -1,
      latitude: 43,
      longitude: -89,
      speed: 0,
      speed_accuracy: -1
    },
    extras: %{
      shift_id: nil,
      status: "working",
      trip_id: nil,
      user_id: 4401
    },
    is_moving: false,
    odometer: 7_468_123,
    timestamp: "2019-07-12T00:00:00.000Z",
    uuid: "df4330e6-d1f1-4df7-80c5-7e6c49940898"
  }

  setup %{conn: conn} do
    user = Factory.create_user()

    conn =
      put_req_header(conn, "accept", "application/json")
      |> TestHelpers.put_auth_header(user)

    {:ok, conn: conn, user: user}
  end

  describe "create points" do
    test "accepts points when data is valid", %{conn: conn, user: user} do
      # random trip id, doesn't matter because it will be ignored
      trip_id = 123_456

      create_attrs1 =
        put_in(@create_attrs, [:extras, :trip_id], trip_id)
        |> Map.put(:timestamp, ~N[2019-07-12 00:00:00])

      create_attrs2 =
        put_in(@create_attrs, [:extras, :trip_id], trip_id)
        |> Map.put(:timestamp, ~N[2019-07-12 00:00:01])
        |> update_in([:coords, :longitude], &(&1 - 0.1))

      create_attrs = [create_attrs1, create_attrs2]

      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # this function will grab lat / long values too
      assert [point1, point2] = Driving.list_points_by_user_id(user.id)

      # point 1 and 2 are flipped because list_points_by_user_id orders by recorded_at
      assert %{
               id: _id,
               recorded_at: ~U[2019-07-12T00:00:01.000000Z],
               latitude: 43.0,
               longitude: -89.1
             } = point1

      assert %{
               id: _id,
               recorded_at: ~U[2019-07-12T00:00:00.000000Z],
               latitude: 43.0,
               longitude: -89.0
             } = point2
    end

    test "tracks device_id when reported", %{conn: conn, user: user} do
      # random trip id, doesn't matter because it will be ignored
      trip_id = 123_456

      create_attrs1 =
        put_in(@create_attrs, [:extras, :trip_id], trip_id)
        |> Map.put(:timestamp, ~N[2019-07-12 00:00:00])

      create_attrs = [create_attrs1]

      conn = TestHelpers.put_device_id_header(conn, "Device A")
      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      actual_device = Devices.get_for_user_by_device_id(user.id, "Device A")
      assert not is_nil(actual_device)

      # this function will grab lat / long values too
      assert [point1] = Driving.list_points_by_user_id(user.id)
      assert point1.recorded_at == ~U[2019-07-12T00:00:00.000000Z]
      assert point1.latitude == 43.0
      assert point1.longitude == -89.0
      assert point1.device_id == actual_device.id
    end

    test "accepts points when trip_id is missing", %{conn: conn, user: user} do
      create_attrs = Map.put(@create_attrs, :timestamp, ~N[2019-07-12 00:00:00])

      conn = post(conn, Routes.point_path(conn, :create), location: [create_attrs])

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # this function will grab lat / long values too
      assert [point] = Driving.list_points_by_user_id(user.id)

      assert %{
               id: _id,
               recorded_at: ~U[2019-07-12T00:00:00.000000Z],
               latitude: 43.0,
               longitude: -89.0
             } = point
    end

    test "ignores point when recorded_at is unreasonably old", %{conn: conn, user: user} do
      user_id = user.id

      # invalid because smart phones and gps didn't even exist in 1970
      invalid_trip_attrs =
        @create_attrs
        |> Map.put(:timestamp, ~N[1970-01-01 00:00:00])

      # valid with no trip id
      valid_trip_attrs =
        @create_attrs
        |> Map.put(:timestamp, ~N[2019-07-12 00:02:00])

      create_attrs = [invalid_trip_attrs, valid_trip_attrs]
      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # only the valid point is accepted
      assert [point] = Driving.list_points()

      # lat / long are not checked because Driving.list_points does not grab
      # them
      assert %{
               id: _id,
               user_id: ^user_id,
               recorded_at: ~U[2019-07-12T00:02:00.000000Z]
             } = point
    end

    test "ignores point when status is incorrect", %{conn: conn, user: user} do
      user_id = user.id

      # invalid because the status field is wrong
      invalid_trip_attrs =
        @create_attrs
        |> put_in([:extras, :status], "fake_status")
        |> Map.put(:timestamp, ~N[2019-07-12 00:03:00])

      # valid with no trip id
      valid_trip_attrs =
        @create_attrs
        |> put_in([:extras, :status], "not_working")
        |> Map.put(:timestamp, ~N[2019-07-12 00:04:00])

      create_attrs = [invalid_trip_attrs, valid_trip_attrs]
      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # only the valid point is accepted
      assert [point] = Driving.list_points()

      # lat / long are not checked because Driving.list_points does not grab
      # them
      assert %{
               id: _id,
               user_id: ^user_id,
               recorded_at: ~U[2019-07-12T00:04:00.000000Z],
               status: "not_working"
             } = point
    end

    test "ignores point when extras key is missing", %{conn: conn, user: user} do
      user_id = user.id

      # invalid because "extras" key is missing from request
      invalid_trip_attrs =
        @create_attrs
        |> Map.put(:timestamp, ~N[2019-07-12 00:08:00])
        |> Map.delete(:extras)

      # valid with no trip id
      valid_trip_attrs =
        @create_attrs
        |> Map.put(:timestamp, ~N[2019-07-12 00:09:00])

      create_attrs = [invalid_trip_attrs, valid_trip_attrs]
      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # only the valid point is accepted
      assert [point] = Driving.list_points()

      # lat / long are not checked because Driving.list_points does not grab
      # them
      assert %{
               id: _id,
               user_id: ^user_id,
               recorded_at: ~U[2019-07-12T00:09:00.000000Z]
             } = point
    end

    test "ignores duplicated user_id/recorded_at points", %{conn: conn, user: _user} do
      duplicated_time = ~U[2019-07-12 00:00:00.000000Z]
      create_attrs1 = Map.put(@create_attrs, :timestamp, duplicated_time)
      create_attrs2 = Map.put(@create_attrs, :timestamp, duplicated_time)

      create_attrs = [create_attrs1, create_attrs2]

      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      assert [point] = Driving.list_points()
      assert duplicated_time == Map.get(point, :recorded_at)
    end

    test "ignores point when the latitude or longiture are out of bounds", %{
      conn: conn,
      user: user
    } do
      user_id = user.id

      # invalid because these are the coordinates for London
      invalid_trip_attrs =
        @create_attrs
        |> put_in([:coords, :latitude], 181.5072)
        |> put_in([:coords, :longitude], -182.1276)
        |> Map.put(:timestamp, ~N[2019-07-12 00:08:00])

      # valid point
      valid_trip_attrs =
        @create_attrs
        |> Map.put(:timestamp, ~N[2019-07-12 00:09:00])

      create_attrs = [invalid_trip_attrs, valid_trip_attrs]
      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # only the valid point is accepted
      assert [point] = Driving.list_points()

      # lat / long are not checked because Driving.list_points does not grab
      # them
      assert %{
               id: _id,
               user_id: ^user_id,
               recorded_at: ~U[2019-07-12T00:09:00.000000Z]
             } = point
    end

    test "accepts points at the extreme ends of the US", %{conn: conn, user: _user} do
      # valid, Lake of the Woods in Minnesota
      valid_point_attrs_1 =
        @create_attrs
        |> put_in([:coords, :latitude], 49.384472)
        |> put_in([:coords, :longitude], -95.153389)
        |> Map.put(:timestamp, ~N[2019-07-12 00:08:00])

      # valid, Western Dry Rocks in Florida Keys
      valid_point_attrs_2 =
        @create_attrs
        |> put_in([:coords, :latitude], 24.446667)
        |> put_in([:coords, :longitude], -81.926667)
        |> Map.put(:timestamp, ~N[2019-07-12 00:09:00])

      # valid, West Quoddy Head in Maine
      valid_point_attrs_3 =
        @create_attrs
        |> put_in([:coords, :latitude], 44.815389)
        |> put_in([:coords, :longitude], -66.949778)
        |> Map.put(:timestamp, ~N[2019-07-12 00:10:00])

      # valid, Cape Alava in Washington
      valid_point_attrs_4 =
        @create_attrs
        |> put_in([:coords, :latitude], 48.164167)
        |> put_in([:coords, :longitude], -124.733056)
        |> Map.put(:timestamp, ~N[2019-07-12 00:11:00])

      create_attrs = [
        valid_point_attrs_1,
        valid_point_attrs_2,
        valid_point_attrs_3,
        valid_point_attrs_4
      ]

      conn = post(conn, Routes.point_path(conn, :create), location: create_attrs)

      # response is empty because mobile app ignores it
      assert "" == response(conn, 204)

      # all points are accepted
      points = Driving.list_points()
      assert length(points) == 4
    end
  end

  describe "study attribution via extras.membership_id" do
    setup %{user: user} do
      group = Factory.create_research_group()

      membership =
        %ResearchGroupMembership{}
        |> ResearchGroupMembership.changeset(%{
          user_id: user.id,
          research_group_id: group.id,
          role: "participant",
          enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
          retention_pref_on_unenroll: "keep_collected"
        })
        |> Repo.insert!()

      %{group: group, membership: membership}
    end

    test "stores membership_id when the caller owns the membership", ctx do
      %{conn: conn, membership: membership} = ctx

      attrs = put_in(@create_attrs, [:extras, :membership_id], membership.id)

      conn = post(conn, Routes.point_path(conn, :create), location: [attrs])
      assert "" == response(conn, 204)

      assert [point] = Driving.list_points()
      assert point.membership_id == membership.id
    end

    test "stores a nil membership_id when none is supplied (legacy path)", %{conn: conn} do
      conn = post(conn, Routes.point_path(conn, :create), location: [@create_attrs])
      assert "" == response(conn, 204)

      assert [point] = Driving.list_points()
      assert is_nil(point.membership_id)
    end

    test "drops points claiming a membership the caller does not own", %{conn: conn} do
      other_user = Factory.create_user()
      other_group = Factory.create_research_group()

      other_membership =
        %ResearchGroupMembership{}
        |> ResearchGroupMembership.changeset(%{
          user_id: other_user.id,
          research_group_id: other_group.id,
          role: "participant",
          enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
          retention_pref_on_unenroll: "keep_collected"
        })
        |> Repo.insert!()

      attrs = put_in(@create_attrs, [:extras, :membership_id], other_membership.id)

      conn = post(conn, Routes.point_path(conn, :create), location: [attrs])
      # Still 204: this endpoint never reports per-point outcomes.
      assert "" == response(conn, 204)

      # Dropped rather than stored unattributed, so it cannot escape the
      # other study's retention policy.
      assert Driving.list_points() == []
    end

    test "keeps owned points in a batch that also contains an unowned one", ctx do
      %{conn: conn, membership: membership} = ctx
      other_user = Factory.create_user()
      other_group = Factory.create_research_group()

      other_membership =
        %ResearchGroupMembership{}
        |> ResearchGroupMembership.changeset(%{
          user_id: other_user.id,
          research_group_id: other_group.id,
          role: "participant",
          enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
          retention_pref_on_unenroll: "keep_collected"
        })
        |> Repo.insert!()

      good =
        @create_attrs
        |> put_in([:extras, :membership_id], membership.id)
        |> Map.put(:timestamp, ~N[2019-07-12 00:00:00])

      bad =
        @create_attrs
        |> put_in([:extras, :membership_id], other_membership.id)
        |> Map.put(:timestamp, ~N[2019-07-12 00:00:01])

      conn = post(conn, Routes.point_path(conn, :create), location: [good, bad])
      assert "" == response(conn, 204)

      assert [point] = Driving.list_points()
      assert point.membership_id == membership.id
    end
  end
end
