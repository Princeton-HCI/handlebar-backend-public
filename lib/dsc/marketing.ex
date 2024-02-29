defmodule DriversSeatCoop.Marketing do
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Devices.Device
  alias DriversSeatCoop.Marketing.CampaignParticipant
  alias DriversSeatCoop.Marketing.Campaigns.GoalsSurvey
  alias DriversSeatCoop.Marketing.Campaigns.MileageTrackingIntroSurvey
  alias DriversSeatCoop.Marketing.Campaigns.OnboardingChecklist
  alias DriversSeatCoop.Marketing.CampaignState
  alias DriversSeatCoop.Marketing.PopulationMember
  alias DriversSeatCoop.Marketing.PopulationTypes.ActivitiesNotification
  alias DriversSeatCoop.Marketing.PopulationTypes.MetroArea
  alias DriversSeatCoop.Marketing.PopulationTypes.OnboardingSurveys
  alias DriversSeatCoop.Marketing.PopulationTypes.OnboardingWelcome
  alias DriversSeatCoop.Mixpanel
  alias DriversSeatCoop.Repo

  import Ecto.Query

  @population_types [
    ActivitiesNotification,
    MetroArea,
    OnboardingSurveys,
    OnboardingWelcome
  ]

  def get_active_campaigns do
    [
      OnboardingChecklist.instance(),
      GoalsSurvey.instance(),
      MileageTrackingIntroSurvey.instance()
    ]
  end

  def get_available_campaigns_for_user(
        %User{} = user,
        %Device{} = device,
        campaigns \\ get_active_campaigns()
      ) do
    all_participation = get_campaign_participation(user.id)

    Enum.reduce(campaigns, [], fn campaign, avail_campaigns ->
      campaign_id = "#{campaign.id}"

      # find this campaign's participation
      participation =
        Enum.find(all_participation, fn p -> p.campaign == campaign_id end) ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: campaign_id
          }

      state = CampaignState.new(user, device, participation)

      if is_campaign_available_for_user?(campaign, state) do
        List.insert_at(avail_campaigns, -1, [campaign, participation])
      else
        avail_campaigns
      end
    end)
  end

  # credo:disable-for-next-line
  defp is_campaign_available_for_user?(
         campaign,
         %CampaignState{} = state
       ) do
    versions_included = List.wrap(campaign.app_versions_included)
    versions_excluded = List.wrap(campaign.app_versions_excluded)

    cond do
      # campaign has a device version requirement and user is not on that version
      Enum.any?(versions_included) and
          not does_device_version_match(state.device, versions_included) ->
        false

      # campaign has a device version exclusion and user is on that version
      Enum.any?(versions_excluded) and does_device_version_match(state.device, versions_excluded) ->
        false

      # User is not qualified
      not campaign.is_qualified.(state) ->
        false

      # User is qualified, and this is a new campaign for the user
      is_nil(state.participant) ->
        true

      # User has previously dismissed the campaign
      not is_nil(state.participant.dismissed_on) ->
        false

      # otherwise, show.
      true ->
        true
    end
  end

  def get_campaign(campaign_id, campaigns \\ get_active_campaigns()) do
    campaign_id = "#{campaign_id}"

    campaigns
    |> Enum.find(fn c -> "#{c.id}" == campaign_id end)
  end

  def present_campaign(
        %User{} = user,
        %Device{} = device,
        campaign_id,
        additional_data,
        campaigns \\ get_active_campaigns()
      )
      when is_nil(additional_data) or is_map(additional_data) do
    campaign = get_campaign(campaign_id, campaigns)

    if is_nil(campaign) do
      {:error, :campaign_not_found}
    else
      orig_participant =
        query_campaign_participation()
        |> query_filter_user(user.id)
        |> query_filter_campaign(campaign.id)
        |> Repo.one()

      orig_participant =
        orig_participant ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: "#{campaign.id}"
          }

      updated_participant =
        Map.put(
          orig_participant,
          :additional_data,
          additional_data || orig_participant.additional_data
        )

      state = CampaignState.new(user, device, updated_participant)

      updated_participant = campaign.on_present.(state)

      CampaignParticipant.changeset(orig_participant, updated_participant)
      |> Repo.insert(
        on_conflict: {:replace, [:presented_on_last, :additional_data]},
        conflict_target: [:user_id, :campaign]
      )
    end
  end

  def accept_campaign(
        %User{} = user,
        %Device{} = device,
        campaign_id,
        action_id,
        additional_data,
        campaigns \\ get_active_campaigns()
      )
      when is_nil(additional_data) or is_map(additional_data) do
    campaign = get_campaign(campaign_id, campaigns)

    if is_nil(campaign) do
      {:error, :campaign_not_found}
    else
      orig_participant =
        query_campaign_participation()
        |> query_filter_user(user.id)
        |> query_filter_campaign(campaign.id)
        |> Repo.one()

      orig_participant =
        orig_participant ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: "#{campaign.id}"
          }

      updated_participant =
        Map.put(
          orig_participant,
          :additional_data,
          additional_data || orig_participant.additional_data
        )

      state = CampaignState.new(user, device, updated_participant)

      updated_participant = campaign.on_accept.(state, action_id)

      CampaignParticipant.changeset(orig_participant, updated_participant)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at, :presented_on_first, :user_id]},
        conflict_target: [:user_id, :campaign]
      )
    end
  end

  def postpone_campaign(
        %User{} = user,
        %Device{} = device,
        campaign_id,
        postpone_minutes,
        action_id,
        additional_data,
        campaigns \\ get_active_campaigns()
      )
      when is_integer(postpone_minutes) and (is_nil(additional_data) or is_map(additional_data)) do
    campaign = get_campaign(campaign_id, campaigns)

    if is_nil(campaign) do
      {:error, :campaign_not_found}
    else
      orig_participant =
        query_campaign_participation()
        |> query_filter_user(user.id)
        |> query_filter_campaign(campaign.id)
        |> Repo.one()

      orig_participant =
        orig_participant ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: "#{campaign.id}"
          }

      updated_participant =
        Map.put(
          orig_participant,
          :additional_data,
          additional_data || orig_participant.additional_data
        )

      state = CampaignState.new(user, device, updated_participant)

      updated_participant = campaign.on_postpone.(state, action_id, postpone_minutes)

      CampaignParticipant.changeset(orig_participant, updated_participant)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at, :presented_on_first, :user_id]},
        conflict_target: [:user_id, :campaign]
      )
    end
  end

  def dismiss_campaign(
        %User{} = user,
        %Device{} = device,
        campaign_id,
        action_id,
        additional_data,
        campaigns \\ get_active_campaigns()
      )
      when is_nil(additional_data) or is_map(additional_data) do
    campaign = get_campaign(campaign_id, campaigns)

    if is_nil(campaign) do
      {:error, :campaign_not_found}
    else
      orig_participant =
        query_campaign_participation()
        |> query_filter_user(user.id)
        |> query_filter_campaign(campaign.id)
        |> Repo.one()

      orig_participant =
        orig_participant ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: "#{campaign.id}"
          }

      updated_participant =
        Map.put(
          orig_participant,
          :additional_data,
          additional_data || orig_participant.additional_data
        )

      state = CampaignState.new(user, device, updated_participant)

      updated_participant = campaign.on_dismiss.(state, action_id)

      CampaignParticipant.changeset(orig_participant, updated_participant)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at, :presented_on_first, :user_id]},
        conflict_target: [:user_id, :campaign]
      )
    end
  end

  def save_campaign_state(
        %User{} = user,
        %Device{} = _device,
        campaign_id,
        additional_data,
        campaigns \\ get_active_campaigns()
      )
      when is_nil(additional_data) or is_map(additional_data) do
    campaign = get_campaign(campaign_id, campaigns)

    if is_nil(campaign) do
      {:error, :campaign_not_found}
    else
      orig_participant =
        query_campaign_participation()
        |> query_filter_user(user.id)
        |> query_filter_campaign(campaign.id)
        |> Repo.one()

      orig_participant =
        orig_participant ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: "#{campaign.id}"
          }

      updated_participant =
        Map.put(
          orig_participant,
          :additional_data,
          additional_data || orig_participant.additional_data
        )

      CampaignParticipant.changeset(orig_participant, updated_participant)
      |> Repo.insert(
        on_conflict: {:replace, [:additional_data]},
        conflict_target: [:user_id, :campaign]
      )
    end
  end

  def handle_campaign_custom_action(
        %User{} = user,
        %Device{} = device,
        campaign_id,
        action_id,
        additional_data,
        campaigns \\ get_active_campaigns()
      )
      when is_nil(additional_data) or is_map(additional_data) do
    campaign = get_campaign(campaign_id, campaigns)

    if is_nil(campaign) do
      {:error, :campaign_not_found}
    else
      orig_participant =
        query_campaign_participation()
        |> query_filter_user(user.id)
        |> query_filter_campaign(campaign.id)
        |> Repo.one()

      orig_participant =
        orig_participant ||
          %CampaignParticipant{
            user_id: user.id,
            campaign: "#{campaign.id}"
          }

      updated_participant =
        Map.put(
          orig_participant,
          :additional_data,
          additional_data || orig_participant.additional_data
        )

      state = CampaignState.new(user, device, updated_participant)

      updated_participant = campaign.on_custom_action.(state, action_id)

      # TODO:  This should probably replace everything
      CampaignParticipant.changeset(orig_participant, updated_participant)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at, :presented_on_first, :user_id]},
        conflict_target: [:user_id, :campaign]
      )
    end
  end

  def get_campaign_participation(user_id) do
    query_campaign_participation()
    |> query_filter_user(user_id)
    |> Repo.all()
  end

  def query_campaign_participation do
    from(cp in CampaignParticipant)
  end

  def query_filter_user(qry, user_id_or_ids) do
    user_ids = List.wrap(user_id_or_ids)

    from(cp in qry,
      where: cp.user_id in ^user_ids
    )
  end

  def query_filter_campaign(qry, campaign_or_campaigns) do
    campaign_or_campaigns =
      List.wrap(campaign_or_campaigns)
      |> Enum.map(fn c -> "#{c}" end)

    from(cp in qry,
      where: cp.campaign in ^campaign_or_campaigns
    )
  end

  def query_filter_accepted(qry, accepted \\ true) do
    if accepted do
      from(cp in qry,
        where: not is_nil(cp.accepted_on)
      )
    else
      from(cp in qry,
        where: is_nil(cp.accepted_on)
      )
    end
  end

  def query_filter_dismissed(qry, dismissed \\ true) do
    if dismissed do
      from(cp in qry,
        where: not is_nil(cp.dismissed_on)
      )
    else
      from(cp in qry,
        where: is_nil(cp.dismissed_on)
      )
    end
  end

  def query_filter_postponed(qry, postponed \\ true) do
    qry =
      qry
      |> query_filter_accepted(false)
      |> query_filter_dismissed(false)

    now = DateTime.utc_now()

    if postponed do
      from(cp in qry,
        where: cp.postponed_until > ^now
      )
    else
      from(cp in qry,
        where: is_nil(cp.postponed_until),
        or_where: cp.postponed_until <= ^now
      )
    end
  end

  def get_population_type(population_type_code) do
    @population_types
    |> Enum.find(fn c -> c.get_type_code() == population_type_code end)
  end

  def get_populations_for_user(user_id, population_type_code) do
    population_type_code = "#{population_type_code}"

    from(pm in PopulationMember,
      where: pm.population_type == ^population_type_code,
      where: pm.user_id == ^user_id
    )
    |> Repo.all()
  end

  def assign_populations_to_user(
        %User{} = user,
        population_type_code,
        update_mixpanel \\ true,
        replace_existing \\ false
      ) do
    populations = get_populations_for_user(user.id, population_type_code)

    if Enum.any?(populations) and not replace_existing do
      if update_mixpanel do
        population_codes = Enum.map(populations, fn p -> p.population end)
        Mixpanel.set_population(user, population_type_code, population_codes)
      end

      populations
    else
      population_type = get_population_type(population_type_code)

      population_codes = population_type.select_populations_for_user(user)

      set_populations_for_user(
        user,
        population_type_code,
        population_codes,
        update_mixpanel,
        replace_existing
      )
    end
  end

  def set_populations_for_user(
        %User{} = user,
        population_type_code,
        population_codes,
        update_mixpanel \\ true,
        replace_existing \\ false
      ) do
    population_type_code = "#{population_type_code}"

    population_codes =
      List.wrap(population_codes)
      |> Enum.map(fn p -> "#{p}" end)

    multi = Ecto.Multi.new()

    existing_populations = get_populations_for_user(user.id, population_type_code)

    # if replacing, handle any deletes
    multi =
      if replace_existing do
        Enum.filter(existing_populations, fn pop ->
          not Enum.member?(population_codes, pop.population)
        end)
        |> Enum.reduce(multi, fn pop, m ->
          Ecto.Multi.delete(m, "delete #{pop.population}", pop)
        end)
      else
        multi
      end

    # add new ones
    existing_population_codes = Enum.map(existing_populations, fn pop -> pop.population end)

    population_codes_to_add = population_codes -- existing_population_codes

    multi =
      Enum.reduce(population_codes_to_add, multi, fn population_code, m ->
        changeset =
          PopulationMember.changeset(%PopulationMember{user_id: user.id}, %{
            population_type: population_type_code,
            population: population_code
          })

        Ecto.Multi.insert(m, population_code, changeset,
          on_conflict: {:replace, [:additional_data]},
          conflict_target: [:user_id, :population_type, :population]
        )
      end)

    with {:ok, _} <- Repo.transaction(multi) do
      populations = get_populations_for_user(user.id, population_type_code)
      population_codes = Enum.map(populations, fn p -> p.population end)

      if update_mixpanel do
        Mixpanel.set_population(user, population_type_code, population_codes)
      end

      populations
    end
  end

  def get_population_member_counts(population_type_code) do
    population_type = get_population_type(population_type_code)
    population_type_code = "#{population_type_code}"

    population_counts =
      population_type.get_available_populations()
      |> Enum.reduce(%{}, fn pop, model -> Map.put(model, "#{pop}", 0) end)

    from(pm in PopulationMember,
      select: {pm.population, count()},
      where: pm.population_type == ^population_type_code,
      group_by: [pm.population]
    )
    |> Repo.all()
    |> Enum.reduce(population_counts, fn {pop, cnt}, model ->
      Map.replace(model, pop, cnt)
    end)
  end

  def is_population_member?(user_id, population_type_code, population_or_populations) do
    query_population_member()
    |> query_population_member_filter_user(user_id)
    |> query_population_member_filter_population_type(population_type_code)
    |> query_population_member_filter_population(population_or_populations)
    |> Repo.exists?()
  end

  def query_population_member, do: from(pm in PopulationMember)

  def query_population_member_filter_user(qry, user_id_or_ids) do
    user_id_or_ids = List.wrap(user_id_or_ids)

    from(pm in qry,
      where: pm.user_id in ^user_id_or_ids
    )
  end

  def query_population_member_filter_population_type(qry, population_type_or_types) do
    population_type_or_types =
      List.wrap(population_type_or_types)
      |> Enum.map(fn x -> "#{x}" end)

    from(pm in qry,
      where: pm.population_type in ^population_type_or_types
    )
  end

  def query_population_member_filter_population(qry, population_or_populations) do
    population_or_populations =
      List.wrap(population_or_populations)
      |> Enum.map(fn x -> "#{x}" end)

    from(pm in qry,
      where: pm.population in ^population_or_populations
    )
  end

  defp does_device_version_match(%Device{} = device, version_requirements) do
    version_requirements = List.wrap(version_requirements)

    cond do
      # no requirements
      not Enum.any?(version_requirements) ->
        true

      # requirements but no device
      is_nil(device) ->
        false

      true ->
        Enum.any?(version_requirements, fn version_req ->
          Device.is_version_match?(device, version_req)
        end)
    end
  end
end
