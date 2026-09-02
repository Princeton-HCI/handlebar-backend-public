defmodule DriversSeatCoopWeb.ResearchGroupCollectorControllerTest do
  use DriversSeatCoopWeb.ConnCase

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroupMembership

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

  defp collector_body(extra \\ %{}) do
    %{
      "collector" =>
        Map.merge(
          %{
            "app_name" => "DoorDash",
            "app_package" => "com.dd.doordash",
            "description" => "Offer rating",
            "screen_name" => "Offer screen",
            "screen_landmarks" => ["Decline", "Accept"],
            "data_fields" => [%{"name" => "rating", "graph_query" => "//offer"}]
          },
          extra
        )
    }
  end

  defp create_collector(group_id, attrs \\ %{}) do
    {:ok, collector} =
      Research.create_collector_and_attach(
        group_id,
        Map.merge(
          %{
            app_name: "DoorDash",
            app_package: "com.dd.doordash",
            description: "Offer rating",
            data_fields: [%{name: "rating", graph_query: "//offer"}]
          },
          attrs
        )
      )

    collector
  end

  describe "create POST /api/research/groups/:group_id/collectors" do
    setup :setup_group

    test "persists and returns collection_interval_seconds", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_collector_path(conn, :create, group.id),
          collector_body(%{"collection_interval_seconds" => 3600})
        )

      data = json_response(conn, 201)["data"]
      assert data["collection_interval_seconds"] == 3600

      assert Repo.get!(DriversSeatCoop.Crepe.Collector, data["collector_id"]).collection_interval_seconds ==
               3600
    end

    test "stores nil when the key is omitted", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(Routes.research_group_collector_path(conn, :create, group.id), collector_body())

      data = json_response(conn, 201)["data"]
      assert data["collection_interval_seconds"] == nil

      assert Repo.get!(DriversSeatCoop.Crepe.Collector, data["collector_id"]).collection_interval_seconds ==
               nil
    end

    test "rejects a negative interval", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> post(
          Routes.research_group_collector_path(conn, :create, group.id),
          collector_body(%{"collection_interval_seconds" => -1})
        )

      assert json_response(conn, 422)["errors"]["collection_interval_seconds"]
    end
  end

  describe "update PATCH /api/research/groups/:group_id/collectors/:collector_id" do
    setup :setup_group

    test "updates the interval and leaves description alone", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"collection_interval_seconds" => 300}}
        )

      data = json_response(conn, 200)["data"]
      assert data["collection_interval_seconds"] == 300
      assert data["description"] == "Offer rating"
      # full collector, including its data fields
      assert [%{"name" => "rating"}] = data["datafields"]
    end

    test "updates the description and leaves the interval alone", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id, %{collection_interval_seconds: 300})

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"description" => "Offer rating (renamed)"}}
        )

      data = json_response(conn, 200)["data"]
      assert data["description"] == "Offer rating (renamed)"
      assert data["collection_interval_seconds"] == 300
    end

    test "accepts 0 as back to every-time", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id, %{collection_interval_seconds: 3600})

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"collection_interval_seconds" => 0}}
        )

      assert json_response(conn, 200)["data"]["collection_interval_seconds"] == 0
    end

    test "accepts null as back to every-time", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id, %{collection_interval_seconds: 3600})

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"collection_interval_seconds" => nil}}
        )

      assert json_response(conn, 200)["data"]["collection_interval_seconds"] == nil
    end

    test "rejects a negative interval", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"collection_interval_seconds" => -5}}
        )

      assert json_response(conn, 422)["errors"]["collection_interval_seconds"]
    end

    test "rejects a whitespace-only description", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      collector = create_collector(group.id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"description" => "   "}}
        )

      assert json_response(conn, 422)["errors"]["description"]
    end

    test "returns 404 for a collector that is not in the group", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      other_collector = create_collector(Factory.create_research_group(%{code: "OTHER"}).id)

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, other_collector.id),
          %{"collector" => %{"collection_interval_seconds" => 60}}
        )

      assert json_response(conn, 404)
    end

    test "returns 403 for a participant", ctx do
      %{conn: conn, participant: participant, group: group} = ctx
      collector = create_collector(group.id)

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> patch(
          Routes.research_group_collector_path(conn, :update, group.id, collector.id),
          %{"collector" => %{"collection_interval_seconds" => 60}}
        )

      assert response(conn, 403)
    end
  end

  describe "index_group GET /api/research/groups/:group_id/collectors" do
    setup :setup_group

    test "includes collection_interval_seconds", ctx do
      %{conn: conn, researcher: researcher, group: group} = ctx
      create_collector(group.id, %{collection_interval_seconds: 3600})

      conn =
        TestHelpers.put_auth_header(conn, researcher)
        |> get(Routes.research_group_collector_path(conn, :index_group, group.id))

      assert [%{"collection_interval_seconds" => 3600}] = json_response(conn, 200)["data"]
    end
  end

  describe "index_participant GET /api/research/me/collectors" do
    setup :setup_group

    test "includes collection_interval_seconds in the first tuple element", ctx do
      %{conn: conn, participant: participant, group: group, participant_membership: membership} =
        ctx

      create_collector(group.id, %{collection_interval_seconds: 60})

      conn =
        TestHelpers.put_auth_header(conn, participant)
        |> get(Routes.research_group_collector_path(conn, :index_participant))

      assert [[collector, membership_id, group_name]] = json_response(conn, 200)["data"]
      assert collector["collection_interval_seconds"] == 60
      assert membership_id == membership.id
      assert group_name == group.name
    end
  end
end
