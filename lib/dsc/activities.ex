defmodule DriversSeatCoop.Activities do
  @moduledoc """
  The Activities/Jobs context.
  """

  import Ecto.Query, warn: false
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Activities.Activity
  alias DriversSeatCoop.Activities.ActivityHour
  alias DriversSeatCoop.Irs
  alias DriversSeatCoop.Repo

  require Logger

  @hour_seconds 3600

  def work_earning_types, do: ["work"]
  def work_activity_statuses, do: ["completed", "cancelled"]

  def get_activity(user_id, activity_id) do
    from(a in get_activities_query(user_id),
      where: a.id == ^activity_id
    )
    |> Repo.one()
  end

  def get_activity_by_activity_id(activity_id) do
    from(a in Activity, where: a.activity_id == ^activity_id)
    |> Repo.one()
  end

  def get_activities(user_id_or_ids, filters \\ %{}) do
    get_activities_query(user_id_or_ids, filters)
    |> Repo.all()
  end

  def get_most_popular_timezone_for_all_users do
    min_date =
      Date.utc_today()
      |> Date.add(-365)

    from(a in Activity)
    |> where([a], a.deleted == false)
    |> where([a], a.working_day_start >= ^min_date)
    |> where([a], not is_nil(a.timezone))
    |> group_by([a], [a.user_id, a.timezone])
    |> select([a], %{
      user_id: a.user_id,
      timezone: a.timezone,
      count: count()
    })
    |> Repo.all(timeout: :infinity)
    |> Enum.group_by(fn x -> x.user_id end)
    |> Map.values()
    |> Enum.map(fn grp ->
      grp
      |> Enum.sort_by(fn x -> x.count end, :desc)
      |> Enum.at(0)
    end)
  end

  def get_activities_query(user_id_or_ids, filters) do
    get_activities_query(user_id_or_ids)
    |> filter_activities_earning_types_included(Map.get(filters, :earning_types))
    |> filter_activities_earning_types_excluded(Map.get(filters, :earning_types_excluded))
    |> filter_activities_status(Map.get(filters, :status))
    |> filter_activities_work_dates(
      Map.get(filters, :work_date_start),
      Map.get(filters, :work_date_end)
    )
  end

  @doc """
  For a user, get the lowest and highest work dates
  """
  def get_activity_date_range(user_id) do
    dates =
      from(a in Activity,
        where: a.user_id == ^user_id,
        select: [
          min(a.working_day_start),
          max(a.working_day_start),
          min(a.working_day_end),
          max(a.working_day_end)
        ]
      )
      |> Repo.one()
      |> Enum.filter(fn x -> not is_nil(x) end)

    if is_nil(dates) or Enum.empty?(dates) do
      [nil, nil]
    else
      [Enum.min(dates, Date), Enum.max(dates, Date)]
    end
  end

  def update_notification_sent(ids) do
    ids = List.wrap(ids)

    notified_on = DateTime.utc_now()

    from(activity in Activity,
      where: activity.id in ^ids
    )
    |> Repo.update_all(
      set: [
        notification_required: false,
        notified_on: notified_on,
        updated_at: notified_on
      ]
    )
  end

  def get_activity_notif_counts_by_date(user_id, since_date \\ nil) do
    qry =
      from(activity in Activity,
        select: %{
          notified_on: activity.notified_on,
          count_activities: count()
        },
        where: activity.user_id == ^user_id,
        where: not is_nil(activity.notified_on),
        group_by: [activity.notified_on]
      )

    qry =
      if is_nil(since_date) do
        qry
      else
        from(activity in qry,
          where: activity.notified_on > ^since_date
        )
      end

    qry
    |> Repo.all()
  end

  def get_activities_query(user_id_or_ids) do
    user_id_or_ids = List.wrap(user_id_or_ids)

    # when only 1 user_id, perform use an "equals" predicate
    # instead of an "in" to improve query performance
    if Enum.count(user_id_or_ids) == 1 do
      user_id_or_ids = Enum.at(user_id_or_ids, 0)

      from(activity in Activity,
        where: activity.user_id == ^user_id_or_ids,
        where: activity.deleted == false
      )
    else
      from(activity in Activity,
        where: activity.user_id in ^user_id_or_ids,
        where: activity.deleted == false
      )
    end
  end

  def filter_activities_require_notification(query) do
    from(a in query,
      where: a.notification_required,
      where: is_nil(a.notified_on)
    )
  end

  def filter_activities_update_date(query, nil = _start_date, nil = _end_date), do: query

  def filter_activities_update_date(query, nil = _start_date, end_date) do
    from(a in query,
      where: a.updated_at <= ^end_date
    )
  end

  def filter_activities_update_date(query, start_date, nil = _end_date) do
    from(a in query,
      where: a.updated_at >= ^start_date
    )
  end

  def filter_activities_update_date(query, start_date, end_date) do
    query
    |> filter_activities_update_date(start_date, nil)
    |> filter_activities_update_date(nil, end_date)
  end

  def filter_activities_work_dates(query, nil, nil) do
    query
  end

  def filter_activities_work_dates(query, work_date_start, nil) do
    from(a in query,
      where: a.working_day_start >= ^work_date_start
    )
  end

  def filter_activities_work_dates(query, nil, work_date_end) do
    from(a in query,
      where: a.working_day_start <= ^work_date_end
    )
  end

  def filter_activities_work_dates(query, work_date_start, work_date_end) do
    from(a in query,
      where:
        fragment(
          "? BETWEEN ? and ? OR ? BETWEEN ? and ? OR (? < ? and ? > ?)",
          a.working_day_start,
          ^work_date_start,
          ^work_date_end,
          a.working_day_end,
          ^work_date_start,
          ^work_date_end,
          ^work_date_start,
          a.working_day_start,
          ^work_date_end,
          a.working_day_end
        )
    )
  end

  def filter_activities_employer(query, employer_or_employers, include \\ true) do
    employer_or_employers =
      List.wrap(employer_or_employers)
      |> Enum.map(fn e -> "#{e}" end)

    if include,
      do: where(query, [a], a.employer in ^employer_or_employers),
      else: where(query, [a], a.employer not in ^employer_or_employers)
  end

  def filter_activities_status(query, nil = _statuses) do
    query
  end

  def filter_activities_status(query, statuses) do
    statuses = List.wrap(statuses)

    from(a in query,
      where: a.status in ^statuses
    )
  end

  def filter_activities_service_class(query, classes, include \\ true) do
    classes =
      List.wrap(classes)
      |> Enum.map(fn c -> "#{c}" end)

    if include do
      where(query, [a], a.service_class in ^classes)
    else
      where(query, [a], a.service_class not in ^classes)
    end
  end

  def filter_activities_earning_types_included(query, nil = _earning_types) do
    query
  end

  def filter_activities_earning_types_included(query, earning_types) do
    earning_types = List.wrap(earning_types)

    from(a in query,
      where: a.earning_type in ^earning_types
    )
  end

  def filter_activities_earning_types_excluded(query, nil = _earning_types) do
    query
  end

  def filter_activities_earning_types_excluded(query, earning_types) do
    earning_types = List.wrap(earning_types)

    from(a in query,
      where: a.earning_type not in ^earning_types
    )
  end

  def identify_timezone_for_user_work_date(user, work_date) do
    qry_base =
      get_activities_query(user.id)
      |> filter_activities_earning_types_included(work_earning_types())
      |> filter_activities_status(work_activity_statuses())
      |> where([a], not is_nil(a.timezone))
      |> select([a], a.timezone)
      |> limit([a], 1)

    # identify the timezone for the user based on their work data
    timezone =
      qry_base
      |> filter_activities_work_dates(nil, work_date)
      |> order_by([a], desc: a.working_day_start)
      |> Repo.one(timeout: :infinity)

    timezone =
      if is_nil(timezone) do
        qry_base
        |> filter_activities_work_dates(work_date, nil)
        |> order_by([a], asc: a.working_day_start)
        |> Repo.one(timeout: :infinity)
      else
        timezone
      end

    if is_nil(timezone), do: User.timezone(user), else: timezone
  end

  def get_activity_hours_for_activity(activity_id) do
    from(ah in ActivityHour)
    |> where([ah], ah.activity_id == ^activity_id)
    |> Repo.all()
  end

  def update_activity_hours(activity_id) do
    activity =
      from(a in Activity)
      |> preload([a], :user)
      |> where([a], a.id == ^activity_id)
      |> Repo.one()

    update_activity_hours(activity, activity.user)
  end

  def update_activity_hours(%Activity{} = activity, %User{} = user) do
    existing_hours = get_activity_hours_for_activity(activity.id)

    calc_hours = calculate_activity_hours(activity, user)

    multi = Ecto.Multi.new()

    {multi, to_be_removed} =
      Enum.reduce(calc_hours, {multi, existing_hours}, fn calc_hour, {m, remaining} ->
        match =
          Enum.find(remaining, fn x ->
            x.date_local == calc_hour.date_local and x.hour_local == calc_hour.hour_local
          end)

        remaining =
          if is_nil(match),
            do: remaining,
            else: Enum.reject(remaining, fn x -> x.id == match.id end)

        changeset = ActivityHour.changeset(match || %ActivityHour{}, calc_hour)

        m =
          Ecto.Multi.insert_or_update(
            m,
            "upsert #{calc_hour.date_local}_#{calc_hour.hour_local}",
            changeset,
            on_conflict: {:replace_all_except, [:inserted_at]},
            conflict_target: [:activity_id, :date_local, :hour_local]
          )

        {m, remaining}
      end)

    multi =
      Enum.reduce(to_be_removed, multi, fn item, m ->
        Ecto.Multi.delete(m, "Delete #{item.id}", item)
      end)

    Repo.transaction(multi)
  end

  def calculate_activity_hours(%Activity{} = activity, %User{} = user) do
    timezone = activity.timezone || User.timezone(user)

    cond do
      is_nil(timezone) ->
        []

      is_nil(activity.timestamp_insights_work_start) or is_nil(activity.timestamp_work_end) ->
        []

      activity.timestamp_insights_work_start == activity.timestamp_work_end ->
        []

      (activity.earnings_total_cents || 0) <= 0 ->
        []

      true ->
        calculate_activity_hours(activity, timezone)
    end
  end

  @doc """
  Break out the activity into each local hour that was worked apportioning a percent
  of the earnings and miles to that hour.  Identify the start of week, work day, and
  work hour.  This is the basis for the Community Insights calculations
  """
  def calculate_activity_hours(%Activity{} = activity, timezone) do
    utc_start = DateTime.to_unix(activity.timestamp_insights_work_start)
    utc_end = DateTime.to_unix(activity.timestamp_work_end)
    activity_duration_seconds = utc_end - utc_start
    earnings_total_cents = activity.earnings_total_cents || 0

    utc_start_hour = utc_start - rem(utc_start, @hour_seconds)
    utc_end_hour = utc_end - rem(utc_end, @hour_seconds)

    Range.new(utc_start_hour, utc_end_hour, @hour_seconds)
    |> Enum.to_list()
    |> Enum.map(fn h ->
      work_hour_utc = DateTime.from_unix!(h)

      work_hour_local =
        DateTime.shift_zone!(work_hour_utc, timezone)
        |> DateTime.to_naive()

      %{
        work_hour_local: work_hour_local,
        duration_seconds: Enum.min([utc_end, h + @hour_seconds]) - Enum.max([utc_start, h])
      }
    end)
    # Group by local hour b/c there's a chance that during Daylight savings, the same hour can appear
    # in the list twice.
    |> Enum.group_by(fn h -> h.work_hour_local end, fn h -> Map.get(h, :duration_seconds) end)
    |> Enum.to_list()
    |> Enum.map(fn {k, v} ->
      date_local = NaiveDateTime.to_date(k)
      duration_seconds = Enum.sum(v)
      percent_of_activity = duration_seconds / activity_duration_seconds

      result = %{
        activity_id: activity.id,
        week_start_date: Date.beginning_of_week(date_local, :sunday),
        date_local: date_local,
        day_of_week: Date.day_of_week(date_local, :sunday) - 1,
        hour_local: NaiveDateTime.to_time(k),
        duration_seconds: duration_seconds,
        percent_of_activity: Float.round(percent_of_activity, 3),
        earnings_total_cents: round(earnings_total_cents * percent_of_activity)
      }

      miles =
        if is_nil(activity.distance) or Decimal.equal?(activity.distance, Decimal.new(0)),
          do: nil,
          else:
            Decimal.mult(activity.distance, Decimal.from_float(percent_of_activity))
            |> Decimal.round(2)

      deduction_mileage_cents = Irs.calculate_irs_expense(date_local, miles)

      result
      |> Map.put(:distance_miles, miles)
      |> Map.put(:deduction_mileage_cents, deduction_mileage_cents)
    end)
  end

  def query_activity_hours, do: from(ah in ActivityHour)

  def query_activity_hours_filter_activity(qry, activity_id_or_ids) do
    activity_id_or_ids = List.wrap(activity_id_or_ids)
    where(qry, [ah], ah.activity_id in ^activity_id_or_ids)
  end

  def query_activity_hours_filter_week(qry, week_start_date_or_dates) do
    week_start_date_or_dates = List.wrap(week_start_date_or_dates)
    where(qry, [ah], ah.week_start_date in ^week_start_date_or_dates)
  end

  defmodule Migration do
    alias DriversSeatCoop.Activities

    def backfill_activity_fields(batch_size),
      do: backfill_activity_fields(batch_size, 0, %{}, %{}, %{})

    def backfill_activity_fields(
          batch_size,
          activity_id,
          service_class_cache,
          employer_cache,
          employer_service_class_cache
        ) do
      activities =
        from(a in Activity,
          preload: [:user],
          where: a.id > ^activity_id,
          limit: ^batch_size,
          order_by: [asc: a.id]
        )

      if Enum.any?(activities) do
        max_activity_id =
          activities
          |> Enum.map(fn a -> a.id end)
          |> Enum.max()

        min_activity_id =
          activities
          |> Enum.map(fn a -> a.id end)
          |> Enum.min()

        Logger.warn(
          "#{DateTime.utc_now()}: Batch - Activity Range #{min_activity_id}  -  #{max_activity_id}"
        )

        {service_class_cache, employer_cache, employer_service_class_cache} =
          Enum.reduce(
            activities,
            {service_class_cache, employer_cache, employer_service_class_cache},
            fn a, {scc, ec, escc} ->
              {cs, scc, ec, escc} =
                Activity.changeset(a, a.user, Map.from_struct(a), scc, ec, escc)

              Repo.update(cs)

              {scc, ec, escc}
            end
          )

        backfill_activity_fields(
          batch_size,
          max_activity_id,
          service_class_cache,
          employer_cache,
          employer_service_class_cache
        )
      end
    end

    def backfill_activity_hours(
          batch_size,
          working_day_start = %Date{} \\ Date.add(Date.utc_today(), -365),
          start_id \\ 0
        ) do
      activities =
        from(a in Activity,
          preload: [:user],
          where: a.id > ^start_id,
          limit: ^batch_size,
          order_by: [asc: a.id]
        )
        |> Repo.all(timeout: :infinity)

      if Enum.any?(activities) do
        max_activity_id =
          activities
          |> Enum.map(fn a -> a.id end)
          |> Enum.max()

        min_activity_id =
          activities
          |> Enum.map(fn a -> a.id end)
          |> Enum.min()

        Logger.warn(
          "#{DateTime.utc_now()}: Batch - Activity Range #{min_activity_id}  -  #{max_activity_id}"
        )

        activities
        |> Enum.filter(fn activity ->
          not is_nil(activity.working_day_start) and
            Date.compare(activity.working_day_start, working_day_start) in [:gt, :eq]
        end)
        |> Enum.each(fn activity ->
          Activities.update_activity_hours(activity, activity.user)
        end)

        backfill_activity_hours(
          batch_size,
          working_day_start,
          max_activity_id
        )
      end
    end
  end
end
