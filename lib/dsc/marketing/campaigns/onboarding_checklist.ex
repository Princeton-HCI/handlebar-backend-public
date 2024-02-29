defmodule DriversSeatCoop.Marketing.Campaigns.OnboardingChecklist do
  alias DriversSeatCoop.GigAccounts
  alias DriversSeatCoop.Goals
  alias DriversSeatCoop.Marketing.Campaign
  alias DriversSeatCoop.Marketing.CampaignAction
  alias DriversSeatCoop.Marketing.CampaignState
  alias DriversSeatCoop.Marketing.Checklist
  alias DriversSeatCoop.Marketing.ChecklistItem
  alias DriversSeatCoop.Repo

  def instance do
    Checklist.new(:onboarding_checklist)
    |> Campaign.with_category(:to_dos)
    |> Campaign.is_qualified(fn %CampaignState{} = state -> is_qualified(state) end)
    |> Checklist.with_title("Finish Setting Up Driver's Seat")
    |> Checklist.show_progress()
    |> Checklist.with_item(fn %CampaignState{} = state -> get_items(state) end)
  end

  defp is_qualified(%CampaignState{} = state) do
    items =
      [
        get_gig_accounts_item(state),
        get_goals_item(state),
        get_mileage_tracking_item(state)
      ]
      |> Enum.filter(fn i -> not is_nil(i) end)

    Enum.any?(items, fn item -> item.status != :complete end)
  end

  defp get_items(%CampaignState{} = state) do
    items =
      [
        get_gig_accounts_item(state),
        get_goals_item(state),
        get_mileage_tracking_item(state)
      ]
      |> Enum.filter(fn i -> not is_nil(i) end)

    if Enum.any?(items, fn item -> item.status != :complete end),
      do: items,
      else: [
        ChecklistItem.new(:up_to_date)
        |> ChecklistItem.with_status(:complete)
        |> ChecklistItem.with_title("You're all set!")
      ]
  end

  defp get_gig_accounts_item(%CampaignState{} = state) do
    item =
      ChecklistItem.new(:connect_accounts)
      |> ChecklistItem.with_title("Connect Your Gig Accounts")
      |> ChecklistItem.with_action(
        CampaignAction.new(:gig_account, :custom, "Manage Gig Accounts")
        |> CampaignAction.with_url("gig-accounts")
      )

    gig_accounts =
      GigAccounts.query()
      |> GigAccounts.query_filter_user(state.user.id)
      |> Repo.all()

    cond do
      # no gig accounts -> not-started
      not Enum.any?(gig_accounts) ->
        item
        |> ChecklistItem.with_status(:not_started)

      # all accounts connected -> complete
      Enum.all?(gig_accounts, fn g -> g.is_connected end) ->
        item
        |> ChecklistItem.with_status(:complete)

      true ->
        item
        |> ChecklistItem.with_status(:requires_attention)
    end
  end

  defp get_goals_item(%CampaignState{} = state) do
    item =
      ChecklistItem.new(:set_goals)
      |> ChecklistItem.with_title("Set Earnings Goals")
      |> ChecklistItem.with_action(
        CampaignAction.new(:goals, :custom, "Manage Goals")
        |> CampaignAction.with_url("goals")
      )

    has_goals =
      Goals.query_goals()
      |> Goals.query_goals_filter_user(state.user.id)
      |> Goals.query_goals_filter_type(:earnings)
      |> Repo.exists?()

    if has_goals,
      do: ChecklistItem.with_status(item, :complete),
      else: ChecklistItem.with_status(item, :not_started)
  end

  defp get_mileage_tracking_item(%CampaignState{} = state) do
    item =
      ChecklistItem.new(:track_mileage)
      |> ChecklistItem.with_title("Set-up Mileage Tracking")
      |> ChecklistItem.with_action(
        CampaignAction.new(:mileage_tracking, :custom, "Mileage Tracking")
        |> CampaignAction.with_url("shifts/help")
      )

    is_configured = state.device.location_tracking_config_status == "configured"

    if is_configured,
      do: ChecklistItem.with_status(item, :complete),
      else: ChecklistItem.with_status(item, :not_started)
  end
end
