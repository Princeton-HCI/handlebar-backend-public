defmodule DriversSeatCoopWeb.ResearchGroupMembershipView do
  use DriversSeatCoopWeb, :view
  alias DriversSeatCoopWeb.ResearchGroupMembershipView

  def render("index.json", %{memberships: ms}) do
    %{data: render_many(ms, ResearchGroupMembershipView, "member.json")}
  end

  def render("member.json", %{research_group_membership: m}) do
    %{
      membership_id: m.id,
      user_id: m.user_id,
      role: m.role,
      first_name: m.user.first_name,
      last_name:  m.user.last_name,
      enrolled_at: m.enrolled_at,
      unenrolled_at: m.unenrolled_at,
      retention_pref_on_unenroll: m.retention_pref_on_unenroll
    }
  end
end
