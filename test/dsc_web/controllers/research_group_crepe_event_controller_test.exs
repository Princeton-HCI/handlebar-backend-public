defmodule DriversSeatCoopWeb.ResearchGroupCrepeEventControllerTest do
  use DriversSeatCoopWeb.ConnCase

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.ResearchGroupMembership

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # Builds a participant who is an active member of a fresh group, plus a
  # collector/data_field attached to that group. Returns the pieces the
  # POST /crepe-event body needs.
  defp setup_participant(_) do
    user = Factory.create_user()
    group = Factory.create_research_group()
    membership = create_membership(user.id, group.id)

    {:ok, collector} =
      Research.create_collector_and_attach(group.id, %{
        app_name: "DoorDash",
        app_package: "com.dd.driverapp",
        description: "test 1 doordash",
        data_fields: [%{name: "Offer Amount", graph_query: "//offer"}]
      })

    [data_field | _] = collector.data_fields

    %{user: user, group: group, membership: membership, data_field: data_field}
  end

  defp create_membership(user_id, group_id, role \\ "participant") do
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

  defp event_body(membership_id, data_field_id) do
    %{
      "crepe_event" => %{
        "data_field_id" => data_field_id,
        "membership_id" => membership_id,
        "collected_at" => "2026-06-16T14:30:00Z",
        "content" => ~s({"values":{"nodeText":"$12.50"},"dataFieldName":"Offer Amount"})
      }
    }
  end

  describe "create POST /api/research/crepe-event" do
    setup :setup_participant

    test "persists an event for an owned active membership", ctx do
      %{conn: conn, user: user, membership: membership, data_field: data_field} = ctx

      conn =
        TestHelpers.put_auth_header(conn, user)
        |> post(
          Routes.research_group_crepe_event_path(conn, :create),
          event_body(membership.id, data_field.id)
        )

      assert response(conn, 201)

      page = Research.list_crepe_events(user_id: user.id)
      assert [event] = page.entries
      assert event.membership_id == membership.id
      assert event.data_field_id == data_field.id
      assert event.user_id == user.id
    end

    test "rejects a membership the caller does not own with 404", ctx do
      %{conn: conn, group: group, membership: membership, data_field: data_field} = ctx

      # A different user attempting to write against someone else's membership id.
      other_user = Factory.create_user()
      _ = create_membership(other_user.id, group.id)

      conn =
        TestHelpers.put_auth_header(conn, other_user)
        |> post(
          Routes.research_group_crepe_event_path(conn, :create),
          event_body(membership.id, data_field.id)
        )

      assert json_response(conn, 404)
      assert Research.list_crepe_events(user_id: other_user.id).entries == []
    end

    test "returns 422 when required fields are missing", ctx do
      %{conn: conn, user: user, membership: membership} = ctx

      body = %{"crepe_event" => %{"membership_id" => membership.id}}

      conn =
        TestHelpers.put_auth_header(conn, user)
        |> post(Routes.research_group_crepe_event_path(conn, :create), body)

      assert json_response(conn, 422)["errors"]
    end
  end
end
