defmodule DriversSeatCoop.Marketing.Campaigns.MileageTrackingIntroSurvey do
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Devices.Device
  alias DriversSeatCoop.Driving
  alias DriversSeatCoop.GigAccounts
  alias DriversSeatCoop.Irs
  alias DriversSeatCoop.Marketing.Campaign
  alias DriversSeatCoop.Marketing.CampaignAction
  alias DriversSeatCoop.Marketing.CampaignParticipant
  alias DriversSeatCoop.Marketing.CampaignState
  alias DriversSeatCoop.Marketing.Survey
  alias DriversSeatCoop.Marketing.SurveyItem
  alias DriversSeatCoop.Marketing.SurveySection
  alias DriversSeatCoop.Repo

  @reengage_delay 60 * 5
  def instance do
    survey = Survey.new(:mileage_tracking_intro)

    survey
    |> Campaign.with_category(:interrupt)
    |> Campaign.is_qualified(fn %CampaignState{} = state ->
      is_qualified?(state.user, state.device, state.participant)
    end)
    |> Survey.with_section(
      SurveySection.new(:welcome)
      |> SurveySection.with_title("Track your Total Work Miles!")
      |> SurveySection.with_item(fn %CampaignState{} ->
        rate = Irs.current_deduction_rate()

        [
          SurveyItem.info()
          |> SurveyItem.with_title(
            "Did you know tracking your work miles in Driver's Seat can help you better understand and even increase your net pay?"
          ),
          SurveyItem.spacer(),
          SurveyItem.content("#{survey.id}/banner.png"),
          SurveyItem.spacer(),
          SurveyItem.info()
          |> SurveyItem.with_description(
            "If you drive a car for gig work, you can deduct #{rate}¢/mile you drive from your taxable income."
          ),
          SurveyItem.info()
          |> SurveyItem.with_description(
            "Gig apps often don't report your total mileage to inflate your take-home pay numbers."
          ),
          SurveyItem.spacer(),
          SurveyItem.info()
          |> SurveyItem.with_title(
            "Tracking your total mileage is easy, and can help you save hundreds or even thousands of dollars each year, depending on how much you drive."
          )
        ]
      end)
      |> SurveySection.hide_page_markers()
      |> SurveySection.hide_page_navigation()
      |> SurveySection.with_action([
        CampaignAction.new(:accept, :accept, "I Want to Track my Total Work Miles")
        |> CampaignAction.with_url("shifts/help")
        |> CampaignAction.with_reengage_delay(@reengage_delay),
        CampaignAction.default_dismiss_link(),
        CampaignAction.default_postpone_link()
      ])
    )
  end

  def is_qualified?(%User{} = user, %Device{} = device, %CampaignParticipant{} = _participation) do
    cond do
      # User has not connected any gig accounts yet -> not qualified
      not user_has_connected_gig_account(user.id) ->
        false

      # Device reports status as != configured -> qualified
      not is_nil(device.location_tracking_config_status) and
          device.location_tracking_config_status != "configured" ->
        true

      # User hasn't tracked any locations in > 30 days -> qualified
      not user_has_locations_tracked(user.id) ->
        true

      # otherwise not qualified
      true ->
        false
    end
  end

  defp user_has_connected_gig_account(user_id) do
    GigAccounts.query()
    |> GigAccounts.query_filter_user(user_id)
    |> GigAccounts.query_filter_is_connected()
    |> Repo.exists?()
  end

  @location_window_seconds 30 * 24 * 60 * 60 * -1

  defp user_has_locations_tracked(user_id) do
    cutoff_date =
      DateTime.utc_now()
      |> DateTime.add(@location_window_seconds, :second)

    Driving.query_points_by_user_id(user_id, %{
      date_start: cutoff_date
    })
    |> Repo.exists?()
  end
end
