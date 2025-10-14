defmodule DriversSeatCoop.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import Argon2, only: [verify_pass: 2, no_user_verify: 0]

  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Accounts.UserAction
  alias DriversSeatCoop.Accounts.UserServiceIdentifier
  alias DriversSeatCoop.Activities.Activity
  alias DriversSeatCoop.Activities.ActivityHour
  alias DriversSeatCoop.AppPreferences.UserAppPreference
  alias DriversSeatCoop.Devices.Device
  alias DriversSeatCoop.Driving
  alias DriversSeatCoop.Driving.Point
  alias DriversSeatCoop.Earnings.Timespan
  alias DriversSeatCoop.Earnings.TimespanAllocation
  alias DriversSeatCoop.Expenses.Expense
  alias DriversSeatCoop.GigAccounts.UserGigAccount
  alias DriversSeatCoop.Goals.Goal
  alias DriversSeatCoop.Goals.GoalMeasurement
  alias DriversSeatCoop.Legal
  alias DriversSeatCoop.Legal.AcceptedTerms
  alias DriversSeatCoop.Legal.Terms
  alias DriversSeatCoop.Marketing.CampaignParticipant
  alias DriversSeatCoop.Marketing.Oban.UpdatePopulationMemberships
  alias DriversSeatCoop.Marketing.PopulationMember
  alias DriversSeatCoop.ReferralSource
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research
  alias DriversSeatCoop.Research.FocusGroupMembership
  alias DriversSeatCoop.ScheduledShifts.ScheduledShift
  alias DriversSeatCoop.Shifts.Shift

  @api_auth_salt "user_api_auth_salt"
  @api_token_max_age 60 * 60 * 24 * 90

  def get_users_query(include_deleted \\ false) do
    qry = from(u in User)

    if include_deleted,
      do: qry,
      else: filter_for_deleted(qry, false)
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    User
    |> order_by(:id)
    |> Repo.all()
  end

  def get_users_with_earnings_query do
    from(u in get_users_query())
    |> filter_non_prod_users_query()
    |> filter_include_users_with_earnings_query()
  end

  def filter_users_in_metro_area(qry, metro_area_id_or_ids, include \\ true) do
    metro_area_id_or_ids = List.wrap(metro_area_id_or_ids)

    if include,
      do: where(qry, [u], u.metro_area_id in ^metro_area_id_or_ids),
      else: where(qry, [u], u.metro_area_id not in ^metro_area_id_or_ids)
  end

  def filter_users_in_focus_group_query(qry, focus_group_id_or_ids, include \\ true) do
    focus_group_id_or_ids = List.wrap(focus_group_id_or_ids)

    if include do
      where(
        qry,
        [u],
        fragment(
          "? IN (SELECT user_id FROM focus_group_memberships where unenroll_date IS NULL AND focus_group_id = ANY(?))",
          u.id,
          ^focus_group_id_or_ids
        )
      )
    else
      where(
        qry,
        [u],
        fragment(
          "? NOT IN (SELECT user_id FROM focus_group_memberships where unenroll_date IS NULL AND focus_group_id = ANY(?))",
          u.id,
          ^focus_group_id_or_ids
        )
      )
    end
  end

  def filter_users_in_any_focus_group_query(qry, include \\ true) do
    if include do
      where(
        qry,
        [u],
        fragment(
          "? IN (SELECT user_id FROM focus_group_memberships where unenroll_date IS NULL)",
          u.id
        )
      )
    else
      where(
        qry,
        [u],
        fragment(
          "? NOT IN (SELECT user_id FROM focus_group_memberships where unenroll_date IS NULL)",
          u.id
        )
      )
    end
  end

  def filter_non_prod_users_query(query, include \\ false) do
    if include do
      from(u in query,
        where: fragment("? ILIKE '%drivers%eat%' OR ? ILIKE '%rokkin%'", u.email, u.email),
        or_where: u.is_demo_account,
        or_where: u.deleted
      )
    else
      from(u in query,
        where: not fragment("? ILIKE '%drivers%eat%' OR ? ILIKE '%rokkin%'", u.email, u.email),
        where: not u.is_demo_account,
        where: not u.deleted
      )
    end
  end

  def filter_has_signed_any_terms_query(query, include \\ true) do
    current_terms_id =
      (Legal.get_current_term() || %{})
      |> Map.get(:id)

    if include do
      from(u in query,
        where:
          fragment(
            "? IN (SELECT user_id FROM accepted_terms WHERE terms_id = ?)",
            u.id,
            ^current_terms_id
          )
      )
    else
      from(u in query,
        where:
          fragment(
            "? NOT IN (SELECT user_id FROM accepted_terms WHERE terms_id = ?)",
            u.id,
            ^current_terms_id
          )
      )
    end
  end

  def filter_users_push_notification_status(query, can_receive \\ true) do
    from(u in query,
      where: u.opted_out_of_push_notifications == not (^can_receive)
    )
  end

  def filter_include_users_with_earnings_query(query) do
    from(u in query)
    |> where(
      [u],
      fragment(
        "EXISTS (SELECT * FROM activities a WHERE a.user_id = ? AND deleted = FALSE)",
        u.id
      )
    )
  end

  def filter_include_users_without_earnings_query(query) do
    from(u in query)
    |> where(
      [u],
      fragment(
        "NOT EXISTS (SELECT * FROM activities a WHERE a.user_id = ? AND deleted = FALSE)",
        u.id
      )
    )
  end

  def filter_include_users_with_earnings_goals_query(query) do
    from(u in query)
    |> where(
      [u],
      fragment(
        "EXISTS (SELECT * FROM goals g WHERE g.user_id = ?)",
        u.id
      )
    )
  end

  def filter_include_users_without_earnings_goals_query(query) do
    from(u in query)
    |> where(
      [u],
      fragment(
        "NOT EXISTS (SELECT * FROM goals g WHERE g.user_id = ?)",
        u.id
      )
    )
  end

  def filter_include_users_with_activities_require_notification(query) do
    from(u in query)
    |> where(
      [u],
      fragment(
        "EXISTS (SELECT * FROM activities a WHERE a.user_id = ? AND a.deleted = FALSE AND a.notification_required = TRUE)",
        u.id
      )
    )
  end

  def filter_by_user_id_query(query, id_or_ids, include \\ true) do
    id_or_ids = List.wrap(id_or_ids)

    if include do
      where(query, [u], u.id in ^id_or_ids)
    else
      where(query, [u], u.id not in ^id_or_ids)
    end
  end

  def filter_for_deleted(query, include \\ true) do
    if include do
      where(query, [u], u.deleted == true)
    else
      where(query, [u], u.deleted == false)
    end
  end

  def get_last_action_date(user_id, filter_events \\ nil) do
    qry =
      from(ua in UserAction,
        select: max(ua.recorded_at),
        where: ua.user_id == ^user_id
      )

    qry =
      if is_nil(filter_events) do
        qry
      else
        filter_events =
          List.wrap(filter_events)
          |> Enum.map(fn event -> "#{event}" end)

        from(ua in qry,
          where: ua.event in ^filter_events
        )
      end

    Repo.one(qry)
  end

  def user_has_earnings?(user_id) do
    from(u in User,
      where: u.id == ^user_id,
      limit: 1
    )
    |> filter_include_users_with_earnings_query()
    |> Repo.exists?()
  end

  def user_has_goals?(user_id) do
    from(g in Goal,
      where: g.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  def list_user_ids do
    from(u in User, select: u.id, order_by: :id)
    |> Repo.all()
  end

  def list_users_where_any_shift_reminder_enabled do
    query_users_can_receive_notification()
    |> where([u], u.remind_shift_start or u.remind_shift_end)
    |> Repo.all()
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user_by_email(email) do
    from(u in get_users_query(), where: [email: ^email])
    |> Repo.one()
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && is_binary(user.password_hash) && verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :bad_credentials}

      true ->
        no_user_verify()
        {:error, :bad_credentials}
    end
  end

  def get_user_by_email_and_role(email, role) do
    from(u in get_users_query(), where: [email: ^email, role: ^role])
    |> Repo.one()
  end

  def is_admin?(%User{role: "admin"}), do: true
  def is_admin?(_), do: false

  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = get_user_by_email_and_role(email, "admin")

    cond do
      admin && is_binary(admin.password_hash) && verify_pass(password, admin.password_hash) ->
        {:ok, admin}

      admin ->
        {:error, :bad_credentials}

      true ->
        no_user_verify()
        {:error, :bad_credentials}
    end
  end

  def reset_password_user(%User{} = user) do
    user
    |> User.reset_password_changeset()
    |> Repo.update()
  end

  def get_user_by_reset_password_token!(token) do
    from(u in get_users_query(),
      where:
        u.reset_password_token == ^token and
          u.reset_password_token_expires_at > ^DateTime.utc_now()
    )
    |> Repo.one!()
  end

  def change_user_password(user) do
    User.change_password_changeset(user, %{})
  end

  def update_user_password(user, attrs) do
    user
    |> User.change_password_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user.

  When creating a user they automatically agree to the tou_v1 and so we
  create an AcceptedTerms to support the robust system as well.
  """
  def create_user(attrs \\ %{}) do
    terms_v1_id = Application.get_env(:dsc, :terms_v1_id)

    changeset =
      %User{}
      |> User.changeset(attrs)
      |> User.registration_changeset(attrs)

    multi = Ecto.Multi.new()
    multi = Ecto.Multi.insert(multi, :create_user, changeset)

    multi =
      if terms_v1_id do
        Ecto.Multi.run(multi, :new_accepted_terms, fn repo, changes ->
          case changes.create_user do
            %User{} = created_user ->
              accepted_terms_changeset =
                Legal.AcceptedTerms.admin_changeset(%Legal.AcceptedTerms{}, %{
                  user_id: created_user.id,
                  terms_id: terms_v1_id,
                  accepted_at: NaiveDateTime.truncate(created_user.inserted_at, :second)
                })

              repo.insert(accepted_terms_changeset)

            _ ->
              {:ok, :no_changes}
          end
        end)
      else
        multi
      end

    Repo.transaction(multi)
    |> case do
      {:ok, %{create_user: result}} -> {:ok, result}
      {:error, :create_user, changeset, _changes} -> {:error, changeset}
    end
  end

  def admin_create_user(attrs \\ %{}) do
    %User{}
    |> User.admin_changeset(attrs)
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    changeset = User.changeset(user, attrs)

    with {:ok, user} <- Repo.update(changeset) do
      update_user_focus_group_membership(user)
      UpdatePopulationMemberships.schedule_job(user.id)
      {:ok, user}
    end
  end

  # credo:disable-for-next-line
  def update_user_focus_group_membership(user) do
    research_group = Research.get_research_group_by_case_insensitive_code(user.focus_group)
    membership = Research.get_current_membership(user.id)

    multi = Ecto.Multi.new()

    multi =
      cond do
        is_nil(research_group) and is_nil(membership) ->
          multi

        is_nil(research_group) or not is_nil(user.unenrolled_research_at) ->
          Research.unenroll_user(multi, user.id)

        is_nil(research_group) and not is_nil(membership) ->
          Research.unenroll_user(multi, user.id)

        not is_nil(research_group) and is_nil(membership) ->
          Research.enroll_user(multi, user.id, research_group.id)

        # active enrollment, but codes dont match: unenroll/enroll
        membership.focus_group_id != research_group.id ->
          multi
          |> Research.unenroll_user(user.id)
          |> Research.enroll_user(user.id, research_group.id)

        true ->
          multi
      end

    Repo.transaction(multi)
  end

  @doc """
  Do a soft delete of the user's account. This only marks it as deleted and does
  not get rid of it from the database
  """
  def delete_user(%User{} = user) do
    user
    |> User.changeset(%{deleted: true})
    |> Repo.update()
  end

  @doc """
  Delete a user completely from the database and remove all other records
  associated with them. This should only be used with test accounts.
  This will fail if the user is the author of any Terms
  This will fail if there are external service links in the db for this user.
  """
  def purge_user!(user_id) do
    user = get_user!(user_id)

    cond do
      user.deleted != true ->
        {:error, :user_has_not_been_marked_for_deletion}

      # User should not have any external system identifiers, these should be cleaned up first
      Repo.exists?(from(xref in UserServiceIdentifier, where: xref.user_id == ^user.id)) ->
        {:error, :user_has_external_system_identifiers}

      # User cannot have authored terms of service
      Repo.exists?(from(t in Terms, where: t.user_id == ^user.id)) ->
        {:error, :user_authored_terms_of_service}

      true ->
        # delete points first because they can be linked to activities / trips
        from(p in Point, where: p.user_id == ^user_id)
        |> Driving.delete_points_query_batch(5000)

        # detach referral sources from the user and set them inactive
        from(rs in ReferralSource, where: rs.user_id == ^user_id)
        |> Repo.update_all(
          set: [
            user_id: nil,
            is_active: false,
            updated_at: DateTime.utc_now()
          ]
        )

        # delete timespan allocations and timespans
        from(alloc in TimespanAllocation,
          join: ts in Timespan,
          on: alloc.timespan_id == ts.id,
          where: ts.user_id == ^user.id
        )
        |> Repo.delete_all(timeout: :infinity)

        from(ts in Timespan, where: ts.user_id == ^user.id) |> Repo.delete_all(timeout: :infinity)

        # delete goals and measurements
        from(gm in GoalMeasurement, where: gm.user_id == ^user_id)
        |> Repo.delete_all(timeout: :infinity)

        from(g in Goal, where: g.user_id == ^user_id) |> Repo.delete_all()

        # order doesn't matter for the rest
        from(a in UserAppPreference, where: a.user_id == ^user_id) |> Repo.delete_all()
        from(a in AcceptedTerms, where: a.user_id == ^user_id) |> Repo.delete_all()

        from(ah in ActivityHour,
          join: a in Activity,
          on: ah.activity_id == a.id,
          where: a.user_id == ^user_id
        )
        |> Repo.delete_all(timeout: :infinity)

        from(a in Activity, where: a.user_id == ^user_id) |> Repo.delete_all(timeout: :infinity)
        from(a in UserAction, where: a.user_id == ^user_id) |> Repo.delete_all(timeout: :infinity)
        from(e in Expense, where: e.user_id == ^user_id) |> Repo.delete_all()
        from(s in Shift, where: s.user_id == ^user_id) |> Repo.delete_all()
        from(s in ScheduledShift, where: s.user_id == ^user_id) |> Repo.delete_all()
        from(cp in CampaignParticipant, where: cp.user_id == ^user_id) |> Repo.delete_all()
        from(pm in PopulationMember, where: pm.user_id == ^user_id) |> Repo.delete_all()
        from(uga in UserGigAccount, where: uga.user_id == ^user_id) |> Repo.delete_all()
        from(fgm in FocusGroupMembership, where: fgm.user_id == ^user_id) |> Repo.delete_all()

        from(d in Device, where: d.user_id == ^user_id) |> Repo.delete_all(timeout: :infinity)

        {:ok, _} = Repo.delete(user, timeout: :infinity)

        {:ok, user}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def token_for_user_id(user_id) when is_integer(user_id) do
    Phoenix.Token.sign(DriversSeatCoopWeb.Endpoint, @api_auth_salt, %{user_id: user_id})
  end

  def verify_token(token) do
    Phoenix.Token.verify(
      DriversSeatCoopWeb.Endpoint,
      @api_auth_salt,
      token,
      max_age: @api_token_max_age
    )
  end

  def send_reset_password_email(user) do
    email = DriversSeatCoopWeb.ResetPasswordEmail.reset_password(user)
    {DriversSeatCoopWeb.Mailer.deliver(email), email}
  end

  def send_data_request_email(user) do
    email = DriversSeatCoopWeb.DataRequestEmail.data_request(user)
    {DriversSeatCoopWeb.Mailer.deliver(email), email}
  end

  def create_login_user_action(user, recorded_at \\ nil) do
    recorded_at =
      if recorded_at do
        recorded_at
        |> NaiveDateTime.truncate(:second)
      else
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)
      end

    %UserAction{user_id: user.id, recorded_at: recorded_at, event: "login"}
    |> UserAction.changeset(%{})
    |> Repo.insert()
  end

  def create_ghost_user_login_action(user, ghost_user) do
    recorded_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    %UserAction{
      user_id: user.id,
      recorded_at: recorded_at,
      event: "admin_ghost_user_login:#{ghost_user.id}"
    }
    |> UserAction.changeset(%{})
    |> Repo.insert()
  end

  def create_reset_password_user_action(user, recorded_at \\ nil) do
    recorded_at =
      if recorded_at do
        recorded_at
        |> NaiveDateTime.truncate(:second)
      else
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)
      end

    %UserAction{user_id: user.id, recorded_at: recorded_at, event: "reset_password"}
    |> UserAction.changeset(%{})
    |> Repo.insert()
  end

  def create_session_refresh_user_action(user, recorded_at \\ nil) do
    recorded_at =
      if recorded_at do
        recorded_at
        |> NaiveDateTime.truncate(:second)
      else
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)
      end

    %UserAction{user_id: user.id, recorded_at: recorded_at, event: "session_refresh"}
    |> UserAction.changeset(%{})
    |> Repo.insert()
  end

  def get_last_user_session_refresh(user_id) do
    from(ua in UserAction,
      where: ua.user_id == ^user_id and ua.event == "session_refresh",
      order_by: [desc: ua.recorded_at],
      limit: 1,
      select: ua.recorded_at
    )
    |> Repo.one()
  end

  import Torch.Helpers, only: [sort: 1, paginate: 4]
  import Filtrex.Type.Config

  @pagination [page_size: 15]
  @pagination_distance 5

  @doc """
  Paginate the list of users using filtrex
  filters.

  ## Examples

      iex> paginate_users(%{})
      %{users: [%User{}], ...}

  """
  @spec paginate_users(map) :: {:ok, map} | {:error, any}
  def paginate_users(params \\ %{}) do
    params =
      params
      |> Map.put_new("sort_direction", "desc")
      |> Map.put_new("sort_field", "inserted_at")

    {:ok, sort_direction} = Map.fetch(params, "sort_direction")
    {:ok, sort_field} = Map.fetch(params, "sort_field")

    with {:ok, filter} <- Filtrex.parse_params(filter_config(:users), params["user"] || %{}),
         %Scrivener.Page{} = page <- do_paginate_users(filter, params) do
      {:ok,
       %{
         users: page.entries,
         page_number: page.page_number,
         page_size: page.page_size,
         total_pages: page.total_pages,
         total_entries: page.total_entries,
         distance: @pagination_distance,
         sort_field: sort_field,
         sort_direction: sort_direction
       }}
    else
      {:error, error} -> {:error, error}
      error -> {:error, error}
    end
  end

  defp do_paginate_users(filter, params) do
    User
    |> Filtrex.query(filter)
    |> order_by(^sort(params))
    |> paginate(Repo, params, @pagination)
  end

  defp query_users_can_receive_notification do
    User
    |> where([u], not u.deleted)
    |> where([u], not u.opted_out_of_push_notifications)
  end

  defp filter_config(:users) do
    defconfig do
      number(:id)
      text(:email)
      text(:first_name)
      text(:last_name)
      text(:phone_number)
      text(:vehicle_make)
      text(:vehicle_model)
      text(:vehicle_type)
      number(:vehicle_year)
      boolean(:contact_permission)
      text(:device_platform)
      text(:focus_group)
      text(:engine_type)
      text(:country)
      text(:postal_code)
      text(:car_ownership)
      text(:role)
      boolean(:deleted)
      text(:timezone)
      text(:timezone_device)
    end
  end

  def backfill_users do
    from(u in User)
    |> Repo.all()
    |> Enum.each(fn u ->
      User.changeset(u, Map.from_struct(u))
      |> Repo.update()
    end)
  end
end
