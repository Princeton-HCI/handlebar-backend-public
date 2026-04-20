defmodule DriversSeatCoopWeb.UserView do
  use DriversSeatCoopWeb, :view
  alias DriversSeatCoopWeb.UserView

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      role: user.role,
      agreed_to_current_terms: Map.get(user, :agreed_to_current_terms, false),
      car_ownership: user.car_ownership,
      contact_permission: user.contact_permission,
      country: user.country,
      currently_on_shift: user.currently_on_shift,
      created_at: user.inserted_at,
      device_platform: user.device_platform,
      email: user.email,
      enabled_features: if(user.role == "admin", do: ["ghosting"], else: []),
      engine_type: user.engine_type,
      enrolled_research_at: user.enrolled_research_at,
      ethnicity: user.ethnicity,
      first_name: user.first_name,
      focus_group: user.focus_group,
      gender: user.gender,
      has_referral_source: !is_nil(user.referral_source_id),
      is_beta: user.is_beta,
      is_demo_account: user.is_demo_account,
      last_name: user.last_name,
      opted_out_of_data_sale_at: user.opted_out_of_data_sale_at,
      opted_out_of_push_notifications: user.opted_out_of_push_notifications,
      opted_out_of_sensitive_data_use_at: user.opted_out_of_sensitive_data_use_at,
      phone_number: user.phone_number,
      postal_code: user.postal_code,
      remind_shift_start: user.remind_shift_start,
      remind_shift_end: user.remind_shift_end,
      service_names: user.service_names,
      source: user.source,
      timezone: user.timezone,
      timezone_device: user.timezone_device,
      unenrolled_research_at: user.unenrolled_research_at,
      vehicle_make: user.vehicle_make,
      vehicle_model: user.vehicle_model,
      vehicle_type: user.vehicle_type,
      vehicle_year: user.vehicle_year,

      # TODO: remove these fields once old versions of the app are no longer in
      # use
      average_gross_pay: 0,
      average_net_pay: 0
    }
  end
end
