defmodule DriversSeatCoopWeb.ResearchGroupMembershipView do
  use DriversSeatCoopWeb, :view

  def render("index.json", %{memberships: ms}) do
    %{data: render_many(ms, __MODULE__, "member.json", as: :research_group_membership)}
  end

  def render("show.json", %{membership: m}) do
    %{data: render_one(m, __MODULE__, "member.json", as: :research_group_membership)}
  end

def render("member.json", %{research_group_membership: m}) do
    %{
      membership_id: m.id,
      user_id: m.user_id,
      role: m.role,
      enrolled_at: m.enrolled_at,
      unenrolled_at: m.unenrolled_at,
      retention_pref_on_unenroll: m.retention_pref_on_unenroll
    }
  end
end
