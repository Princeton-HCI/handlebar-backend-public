defmodule DriversSeatCoopWeb.ResearchGroupSensorControllerTest do
  use DriversSeatCoopWeb.ConnCase

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroupMembership
  alias DriversSeatCoop.Research.SensorConfig

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # A group with one researcher and one participant, both past the terms plug.
  defp setup_group(_) do
    group = Factory.create_research_group()

    researcher = Factory.create_user()
    Factory.accept_current_terms(researcher)
    create_membership(researcher.id, group.id, "researcher")

    participant = Factory.create_user()
    Factory.accept_current_terms(participant)
    participant_membership = create_membership(participant.id, group.id, "participant")

    %{
      group: group,
      researcher: researcher,
      participant: participant,
      participant_membership: participant_membership
    }
  end

  defp create_membership(user_id, group_id, role) do
    %ResearchGroupMembership{}
    |> ResearchGroupMembership.changeset(%{
      user_id: user_id,
      research_group_id: group_id,
      role: role,
      enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
      retention_pref_on_unenroll: "keep_collected"
    })
    |> Repo.insert!()
  end

  defp sensor_body(extra \\ %{}) do
    %{
      "sensor" =>
        Map.merge(
          %{
            "type" => "location",
            "sample_interval_seconds" => 30,
            "trigger_type" => "app_foreground",
            "trigger_app_package" => "com.dd.doordash",
            "timeout_seconds" => 1800
          },
          extra
        )
    }
  end

  defp create_sensor(group_id, attrs \\ %{}) do
    {:ok, sensor} =
      Research.create_sensor_config(
        group_id,
        Map.merge(
          %{
            "type" => "location",
            "sample_interval_seconds" => 30,
            "trigger_type" => "app_foreground",
            "trigger_app_package" => "com.dd.doordash",
            "timeout_seconds" => 1800
          },
          attrs
        )
      )

    sensor
  end

  defp create_collector(group_id) do
    {:ok, collector} =
      Research.create_collector_and_attach(group_id, %{
        app_name: "DoorDash",
        app_package: "com.dd.doordash",
        description: "Offer rating",
        data_fields: [%{name: "rating", graph_query: "//offer"}]
      })

    collector
  end

  describe "create POST /api/research/groups/:group_id/sensors" do
    setup :setup_group

    test "persists and returns a location sensor", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(Routes.research_group_sensor_path(conn, :create, group.id), sensor_body())

      data = json_response(conn, 201)["data"]

      assert data["type"] == "location"
      assert data["enabled"] == true
      assert data["sample_interval_seconds"] == 30
      assert data["trigger_type"] == "app_foreground"
      assert data["trigger_app_package"] == "com.dd.doordash"
      assert data["timeout_seconds"] == 1800

      persisted = Repo.get!(SensorConfig, data["sensor_id"])
      assert persisted.research_group_id == group.id
      assert persisted.sample_interval_seconds == 30
    end

    test "accepts a collector_match trigger", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_sensor_path(conn, :create, group.id),
          sensor_body(%{
            "trigger_type" => "collector_match",
            "trigger_app_package" => nil,
            "trigger_collector_id" => collector.id
          })
        )

      data = json_response(conn, 201)["data"]
      assert data["trigger_type"] == "collector_match"
      assert data["trigger_collector_id"] == collector.id
    end

    test "accepts an always trigger with no target", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_sensor_path(conn, :create, group.id),
          sensor_body(%{"trigger_type" => "always", "trigger_app_package" => nil})
        )

      assert json_response(conn, 201)["data"]["trigger_type"] == "always"
    end

    test "rejects app_foreground trigger with no app package", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_sensor_path(conn, :create, group.id),
          sensor_body(%{"trigger_app_package" => nil})
        )

      assert json_response(conn, 422)["errors"]["trigger_app_package"]
    end

    test "rejects collector_match trigger with no collector", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_sensor_path(conn, :create, group.id),
          sensor_body(%{"trigger_type" => "collector_match", "trigger_app_package" => nil})
        )

      assert json_response(conn, 422)["errors"]["trigger_collector_id"]
    end

    test "rejects a non-positive sample interval", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_sensor_path(conn, :create, group.id),
          sensor_body(%{"sample_interval_seconds" => 0})
        )

      assert json_response(conn, 422)["errors"]["sample_interval_seconds"]
    end

    test "rejects an unknown sensor type", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_sensor_path(conn, :create, group.id),
          sensor_body(%{"type" => "telepathy"})
        )

      assert json_response(conn, 422)["errors"]["type"]
    end

    test "rejects a second config of the same type for one group", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      _existing = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(Routes.research_group_sensor_path(conn, :create, group.id), sensor_body())

      assert json_response(conn, 422)["errors"]
    end

    test "participants may not create sensors", ctx do
      %{conn: conn, participant: participant, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> post(Routes.research_group_sensor_path(conn, :create, group.id), sensor_body())

      assert response(conn, 403)
    end
  end

  describe "update PATCH /api/research/groups/:group_id/sensors/:sensor_id" do
    setup :setup_group

    test "updates the sample interval alone", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_sensor_path(conn, :update, group.id, sensor.id),
          %{"sensor" => %{"sample_interval_seconds" => 10}}
        )

      data = json_response(conn, 200)["data"]
      assert data["sample_interval_seconds"] == 10
      # The trigger target was not resent and must not be demanded again:
      # validate_trigger_target/1 reads merged state, not just the changes.
      assert data["trigger_app_package"] == "com.dd.doordash"
      assert Repo.get!(SensorConfig, sensor.id).sample_interval_seconds == 10
    end

    test "toggles enabled without touching anything else", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_sensor_path(conn, :update, group.id, sensor.id),
          %{"sensor" => %{"enabled" => false}}
        )

      assert json_response(conn, 200)["data"]["enabled"] == false
      refute Repo.get!(SensorConfig, sensor.id).enabled
    end

    test "accepts a null timeout meaning never stop", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_sensor_path(conn, :update, group.id, sensor.id),
          %{"sensor" => %{"timeout_seconds" => nil}}
        )

      assert json_response(conn, 200)["data"]["timeout_seconds"] == nil
    end

    test "rejects switching trigger type without supplying the new target", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_sensor_path(conn, :update, group.id, sensor.id),
          %{"sensor" => %{"trigger_type" => "collector_match"}}
        )

      assert json_response(conn, 422)["errors"]["trigger_collector_id"]
    end

    test "404s for a sensor belonging to another group", ctx do
      %{conn: conn, researcher: researcher} = ctx
      other_group = Factory.create_research_group()
      other_sensor = create_sensor(other_group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_sensor_path(
            conn,
            :update,
            ctx.group.id,
            other_sensor.id
          ),
          %{"sensor" => %{"sample_interval_seconds" => 10}}
        )

      assert json_response(conn, 404)
    end

    test "participants may not update sensors", ctx do
      %{conn: conn, participant: participant, group: group} = ctx
      sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> patch(
          Routes.research_group_sensor_path(conn, :update, group.id, sensor.id),
          %{"sensor" => %{"sample_interval_seconds" => 10}}
        )

      assert response(conn, 403)
    end
  end

  describe "delete DELETE /api/research/groups/:group_id/sensors/:sensor_id" do
    setup :setup_group

    test "removes the sensor", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> delete(Routes.research_group_sensor_path(conn, :delete, group.id, sensor.id))

      assert response(conn, 204)
      refute Repo.get(SensorConfig, sensor.id)
    end

    test "404s for a sensor belonging to another group", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      other_group = Factory.create_research_group()
      other_sensor = create_sensor(other_group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> delete(Routes.research_group_sensor_path(conn, :delete, group.id, other_sensor.id))

      assert json_response(conn, 404)
      assert Repo.get(SensorConfig, other_sensor.id)
    end
  end

  describe "index_group GET /api/research/groups/:group_id/sensors" do
    setup :setup_group

    test "lists sensors including disabled ones", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      sensor = create_sensor(group.id, %{"enabled" => false})

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> get(Routes.research_group_sensor_path(conn, :index_group, group.id))

      assert [returned] = json_response(conn, 200)["data"]
      assert returned["sensor_id"] == sensor.id
      assert returned["enabled"] == false
    end

    test "is readable by participants", ctx do
      %{conn: conn, participant: participant, group: group} = ctx
      _sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> get(Routes.research_group_sensor_path(conn, :index_group, group.id))

      assert length(json_response(conn, 200)["data"]) == 1
    end
  end

  describe "index_participant GET /api/research/me/sensors" do
    setup :setup_group

    test "returns [sensor, membership_id, group_name] triples", ctx do
      %{conn: conn, participant: participant, group: group} = ctx
      sensor = create_sensor(group.id)
      membership = ctx.participant_membership

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> get(Routes.research_group_sensor_path(conn, :index_participant))

      assert [[sensor_json, membership_id, group_name]] = json_response(conn, 200)["data"]
      assert sensor_json["sensor_id"] == sensor.id
      assert sensor_json["trigger_app_package"] == "com.dd.doordash"
      assert membership_id == membership.id
      assert group_name == group.name
    end

    test "omits disabled sensors so devices stop collecting", ctx do
      %{conn: conn, participant: participant, group: group} = ctx
      _sensor = create_sensor(group.id, %{"enabled" => false})

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> get(Routes.research_group_sensor_path(conn, :index_participant))

      assert json_response(conn, 200)["data"] == []
    end

    test "omits sensors from groups the user only researches", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      _sensor = create_sensor(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> get(Routes.research_group_sensor_path(conn, :index_participant))

      assert json_response(conn, 200)["data"] == []
    end
  end
end
