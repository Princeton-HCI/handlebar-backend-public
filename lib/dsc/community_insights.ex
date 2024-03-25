defmodule DriversSeatCoop.CommunityInsights do
  import Ecto.Query, warn: false

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Activities.Activity
  alias DriversSeatCoop.Activities.ActivityHour
  alias DriversSeatCoop.CommunityInsights.AverageHourlyPayStat
  alias DriversSeatCoop.CommunityInsights.AverageHourlyPayStatDSC
  alias DriversSeatCoop.Employers.EmployerServiceClass
  alias DriversSeatCoop.Regions
  alias DriversSeatCoop.Regions.MetroArea
  alias DriversSeatCoop.Repo

  @sixteen_weeks 7 * 16
  @thirtytwo_weeks @sixteen_weeks * 2

  @min_count_users 2
  @min_count_activities 5

  @service_class_id_rideshare 1
  @service_class_id_delivery 2
  @service_class_id_services 3
  @week_timeslot_count 7 * 24
  @decimal_zero Decimal.from_float(0.0)

  @best_employer_fields [
    :employer_service_class_id,
    :earnings_avg_hr_cents,
    :earnings_avg_hr_cents_with_mileage,
    :count_activities,
    :count_tasks,
    :count_users
  ]

  @trend_fields [
    :week_start_date,
    :metro_area_id,
    :employer_service_class_id,
    :day_of_week,
    :hour_local,
    :count_activities,
    :count_tasks,
    :count_users,
    :count_week_samples,
    :duration_seconds,
    :earnings_total_cents,
    :deduction_mileage_cents,
    :distance_miles,
    :earnings_avg_hr_cents,
    :earnings_avg_hr_cents_with_mileage,
    :service_class_id
  ]

  def get_stat_week_start(%Date{} = date), do: Date.beginning_of_week(date, :sunday)

  @doc """
  One way to cut down on processing time is to look at activity data to see which 
  metros actually have data to be calculated.
  """
  def get_metro_areas_in_scope do
    this_week = get_stat_week_start(Date.utc_today())

    start_date = Date.add(this_week, -@thirtytwo_weeks)

    activity_metros =
      from(a in Activity)
      |> where([a], not a.deleted)
      |> where([a], a.working_day_start >= ^start_date)
      |> where([a], not is_nil(a.metro_area_id))
      |> group_by([a], a.metro_area_id)
      |> having(
        [a],
        fragment(
          "count(*) > ? or count(distinct ?) > ?",
          ^@min_count_activities,
          a.user_id,
          ^@min_count_users
        )
      )
      |> select([a], a.metro_area_id)
      |> Repo.all(timeout: :infinity)

    stat_metros =
      from(stat in AverageHourlyPayStat)
      |> group_by([stat], stat.metro_area_id)
      |> select([stat], stat.metro_area_id)
      |> Repo.all(timeout: :infinity)

    (activity_metros ++ stat_metros)
    |> Enum.uniq()
  end

  @doc """
  Returns a list of weeks in scope for insights calcs.
  It is understood that this list will be week start dates in descending order
  """
  def get_weeks_in_scope do
    this_week = get_stat_week_start(Date.utc_today())

    Date.range(this_week, Date.add(this_week, -@sixteen_weeks), -7)
    |> Enum.to_list()
  end

  @doc """
  Calculate hourly pay stats for a metro area for a week.  it is a weighted average
  over the last 16 weeks, with most recent weeks being more heavily weighted
  """
  def calculate_avg_hr_pay_stats_for_metro_week(
        %Date{} = week_start_date,
        metro_area_id,
        min_count_users \\ @min_count_users,
        min_count_activities \\ @min_count_activities
      ) do
    end_window = get_stat_week_start(week_start_date)
    start_window = Date.add(end_window, -@sixteen_weeks)

    non_prod_user_ids_qry =
      Accounts.get_users_query()
      |> Accounts.filter_non_prod_users_query(true)
      |> select([u], u.id)

    from(a in Activity,
      join: ah in ActivityHour,
      on: a.id == ah.activity_id,
      where: a.user_id not in subquery(non_prod_user_ids_qry),
      where: a.metro_area_id == ^metro_area_id,
      # added for performance
      where: a.working_day_start >= ^start_window,
      where: not a.deleted,
      where: not is_nil(a.employer_service_class_id),
      where: ah.week_start_date >= ^start_window,
      where: ah.week_start_date <= ^end_window,
      group_by: [
        ah.day_of_week,
        ah.hour_local,
        a.employer_service_class_id
      ],
      having: sum(ah.duration_seconds) > 0,
      having:
        fragment(
          "COUNT(DISTINCT ?) >= ? OR COUNT(DISTINCT ?) >= ?",
          a.id,
          ^min_count_activities,
          a.user_id,
          ^min_count_users
        ),
      select: %{
        employer_service_class_id: a.employer_service_class_id,
        day_of_week: ah.day_of_week,
        hour_local: ah.hour_local,
        count_activities: fragment("COUNT(DISTINCT ?)", a.id),
        # The minimum number of tasks for an activity/hour would be 1
        # So, if the user did have the task in hour 1 and half in hour 2,
        # both hours count as having 1 task.
        count_tasks:
          fragment(
            "CEIL(SUM(GREATEST(COALESCE(?,1) * ?, 1)))::int",
            a.tasks_total,
            ah.percent_of_activity
          ),
        count_users: fragment("COUNT(DISTINCT ?)", a.user_id),
        count_week_samples: fragment("COUNT(DISTINCT ?)", ah.week_start_date),
        week_sample_first: min(ah.week_start_date),
        week_sample_last: max(ah.week_start_date),
        duration_seconds: sum(ah.duration_seconds),
        earnings_total_cents: sum(ah.earnings_total_cents),
        distance_miles: sum(ah.distance_miles),
        deduction_mileage_cents: sum(fragment("COALESCE(?,0)", ah.deduction_mileage_cents)),
        weighted_earnings_total_cents:
          sum(
            ah.earnings_total_cents *
              fragment("(17 - ((? - ?)/7))", ^end_window, ah.week_start_date)
          ),
        weighted_duration_seconds:
          sum(
            ah.duration_seconds *
              fragment("(17 - ((? - ?)/7))", ^end_window, ah.week_start_date)
          ),
        weighted_deduction_mileage_cents:
          sum(
            fragment("COALESCE(?,0)", ah.deduction_mileage_cents) *
              fragment("(17 - ((? - ?)/7))", ^end_window, ah.week_start_date)
          )
      }
    )
    |> Repo.all(timeout: :infinity)
    |> Enum.filter(fn stat -> stat.weighted_duration_seconds > 0 end)
    |> Enum.map(fn stat ->
      earnings_avg_hr_cents =
        (stat.weighted_earnings_total_cents * 3_600 / stat.weighted_duration_seconds)
        |> Float.round()
        |> trunc()

      earnings_avg_hr_cents_with_mileage =
        ((stat.weighted_earnings_total_cents - stat.weighted_deduction_mileage_cents) *
           3_600 / stat.weighted_duration_seconds)
        |> Float.round()
        |> trunc()

      stat
      |> Map.put(:earnings_avg_hr_cents, earnings_avg_hr_cents)
      |> Map.put(:earnings_avg_hr_cents_with_mileage, earnings_avg_hr_cents_with_mileage)
    end)
  end

  @doc """
  Update community insights calcs for a metro area and week combo
  """
  def update_avg_hr_pay_stats_for_metro_week(
        %Date{} = week_start_date,
        metro_area_id,
        min_count_users \\ @min_count_users,
        min_count_activities \\ @min_count_activities
      ) do
    week_start_date = get_stat_week_start(week_start_date)

    calc_stats =
      calculate_avg_hr_pay_stats_for_metro_week(
        week_start_date,
        metro_area_id,
        min_count_users,
        min_count_activities
      )
      |> Enum.map(fn stat ->
        Map.merge(stat, %{
          week_start_date: week_start_date,
          metro_area_id: metro_area_id
        })
      end)

    existing_stats =
      query()
      |> query_filter_metro_area(metro_area_id)
      |> query_filter_week(week_start_date)
      |> Repo.all()

    to_be_removed =
      Enum.reduce(calc_stats, existing_stats, fn stat, remaining ->
        match =
          Enum.find(remaining, fn x ->
            x.employer_service_class_id == stat.employer_service_class_id and
              x.day_of_week == stat.day_of_week and
              x.hour_local == stat.hour_local
          end)

        remaining =
          if is_nil(match),
            do: remaining,
            else: Enum.reject(remaining, fn x -> x.id == match.id end)

        changeset = AverageHourlyPayStat.changeset(match || %AverageHourlyPayStat{}, stat)

        Repo.insert_or_update!(
          changeset,
          on_conflict: {:replace_all_except, [:inserted_at]},
          conflict_target: [
            :metro_area_id,
            :week_start_date,
            :employer_service_class_id,
            :day_of_week,
            :hour_local
          ]
        )

        remaining
      end)

    if Enum.any?(to_be_removed) do
      to_be_removed_ids =
        to_be_removed
        |> Enum.map(fn x -> x.id end)

      query()
      |> query_filter_id(to_be_removed_ids)
      |> Repo.delete_all(timeout: :infinity)
    end

    :ok
  end

  @doc """
  Use a combo of community insights stats and activities to pull stats for a metro area
  with totals and breakdowns for each service class
  """
  def calculate_metro_area_stats(metro_area_id) do
    most_recent_week =
      query()
      |> query_filter_metro_area(metro_area_id)
      |> select([stat], max(stat.week_start_date))
      |> Repo.one()

    calculate_metro_area_worker_count(metro_area_id)
    |> Map.merge(
      calculate_metro_area_stats_count_users_jobs_tasks_employers(metro_area_id, most_recent_week)
    )
    |> Map.merge(calculate_metro_area_stats_coverage(metro_area_id, most_recent_week))
  end

  @doc """
  Update a metro area with stats calculated from jobs and community insights stats
  """
  def update_metro_area_stats(metro_area_id) do
    stats = calculate_metro_area_stats(metro_area_id)

    metro_area = Regions.get_metro_area_by_id(metro_area_id)

    MetroArea.stats_changeset(metro_area, stats)
    |> Repo.update()
  end

  defp calculate_metro_area_worker_count(metro_area_id) do
    count_users =
      Accounts.get_users_query()
      |> Accounts.filter_non_prod_users_query()
      |> Accounts.filter_users_in_metro_area(metro_area_id)
      |> select([u], count())
      |> Repo.one()

    %{
      count_workers: count_users
    }
  end

  defp calculate_metro_area_stats_coverage(_metro_area_id, nil = _most_recent_week) do
    %{
      hourly_pay_stat_coverage_percent: nil,
      hourly_pay_stat_coverage_percent_rideshare: nil,
      hourly_pay_stat_coverage_percent_delivery: nil,
      hourly_pay_stat_coverage_percent_services: nil
    }
  end

  defp calculate_metro_area_stats_coverage(metro_area_id, most_recent_week) do
    qry =
      query()
      |> query_filter_metro_area(metro_area_id)
      |> query_filter_week(most_recent_week)

    timeslot_stats =
      from(stat in qry,
        join: esc in EmployerServiceClass,
        on: stat.employer_service_class_id == esc.id,
        select: %{
          day_of_week: stat.day_of_week,
          hour_local: stat.hour_local,
          has_rideshare:
            fragment(
              "MAX(CASE WHEN ? = ? THEN 1 ELSE 0 END)",
              esc.service_class_id,
              ^@service_class_id_rideshare
            ),
          has_delivery:
            fragment(
              "MAX(CASE WHEN ? = ? THEN 1 ELSE 0 END)",
              esc.service_class_id,
              ^@service_class_id_delivery
            ),
          has_services:
            fragment(
              "MAX(CASE WHEN ? = ? THEN 1 ELSE 0 END)",
              esc.service_class_id,
              ^@service_class_id_services
            )
        },
        group_by: [
          stat.day_of_week,
          stat.hour_local
        ]
      )
      |> Repo.all()

    %{
      hourly_pay_stat_coverage_percent:
        (Enum.count(timeslot_stats) / @week_timeslot_count)
        |> Decimal.from_float()
        |> Decimal.round(2),
      hourly_pay_stat_coverage_percent_rideshare:
        (Enum.sum(Enum.map(timeslot_stats, fn ts -> ts.has_rideshare end)) /
           @week_timeslot_count)
        |> Decimal.from_float()
        |> Decimal.round(2),
      hourly_pay_stat_coverage_percent_delivery:
        (Enum.sum(Enum.map(timeslot_stats, fn ts -> ts.has_delivery end)) / @week_timeslot_count)
        |> Decimal.from_float()
        |> Decimal.round(2),
      hourly_pay_stat_coverage_percent_services:
        (Enum.sum(Enum.map(timeslot_stats, fn ts -> ts.has_services end)) / @week_timeslot_count)
        |> Decimal.from_float()
        |> Decimal.round(2)
    }
  end

  defp calculate_metro_area_stats_count_users_jobs_tasks_employers(
         _metro_area_id,
         nil = _most_recent_week
       ) do
    %{
      hourly_pay_stat_coverage_count_workers: nil,
      hourly_pay_stat_coverage_count_workers_rideshare: nil,
      hourly_pay_stat_coverage_count_workers_delivery: nil,
      hourly_pay_stat_coverage_count_workers_services: nil,
      hourly_pay_stat_coverage_count_employers: nil,
      hourly_pay_stat_coverage_count_employers_rideshare: nil,
      hourly_pay_stat_coverage_count_employers_delivery: nil,
      hourly_pay_stat_coverage_count_employers_services: nil,
      hourly_pay_stat_coverage_count_jobs: nil,
      hourly_pay_stat_coverage_count_jobs_rideshare: nil,
      hourly_pay_stat_coverage_count_jobs_delivery: nil,
      hourly_pay_stat_coverage_count_jobs_services: nil,
      hourly_pay_stat_coverage_count_tasks: nil,
      hourly_pay_stat_coverage_count_tasks_rideshare: nil,
      hourly_pay_stat_coverage_count_tasks_delivery: nil,
      hourly_pay_stat_coverage_count_tasks_services: nil
    }
  end

  defp calculate_metro_area_stats_count_users_jobs_tasks_employers(
         metro_area_id,
         most_recent_week
       ) do
    start_window = Date.add(most_recent_week, -@sixteen_weeks)

    non_prod_users_qry =
      Accounts.get_users_query(true)
      |> Accounts.filter_non_prod_users_query(true)
      |> select([u], u.id)

    from(a in Activity,
      join: ah in ActivityHour,
      on: a.id == ah.activity_id,
      join: esc in EmployerServiceClass,
      on: a.employer_service_class_id == esc.id,
      where: a.user_id not in subquery(non_prod_users_qry),
      where: a.metro_area_id == ^metro_area_id,
      where: not a.deleted,
      # added for performance
      where: a.working_day_start >= ^start_window,
      where: ah.week_start_date >= ^start_window,
      where: ah.week_start_date <= ^most_recent_week,
      select: %{
        hourly_pay_stat_coverage_count_workers: fragment("COUNT(DISTINCT ?)", a.user_id),
        hourly_pay_stat_coverage_count_workers_rideshare:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_rideshare,
            a.user_id
          ),
        hourly_pay_stat_coverage_count_workers_delivery:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_delivery,
            a.user_id
          ),
        hourly_pay_stat_coverage_count_workers_services:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_services,
            a.user_id
          ),
        hourly_pay_stat_coverage_count_employers:
          fragment("COUNT(DISTINCT ?)", a.employer_service_class_id),
        hourly_pay_stat_coverage_count_employers_rideshare:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_rideshare,
            a.employer_service_class_id
          ),
        hourly_pay_stat_coverage_count_employers_delivery:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_delivery,
            a.employer_service_class_id
          ),
        hourly_pay_stat_coverage_count_employers_services:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_services,
            a.employer_service_class_id
          ),
        hourly_pay_stat_coverage_count_jobs: fragment("COUNT(DISTINCT ?)", a.id),
        hourly_pay_stat_coverage_count_jobs_rideshare:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_rideshare,
            a.id
          ),
        hourly_pay_stat_coverage_count_jobs_delivery:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_delivery,
            a.id
          ),
        hourly_pay_stat_coverage_count_jobs_services:
          fragment(
            "COUNT(DISTINCT CASE WHEN ? = ? THEN ? END)",
            esc.service_class_id,
            ^@service_class_id_services,
            a.id
          ),

        # The minimum number of tasks for an activity/hour would be 1
        # So, if the user did have the task in hour 1 and half in hour 2,
        # both hours count as having 1 task.
        hourly_pay_stat_coverage_count_tasks:
          fragment(
            "COALESCE(CEIL(SUM(GREATEST(COALESCE(?,1) * ?, 1)))::int,0)",
            a.tasks_total,
            ah.percent_of_activity
          ),
        hourly_pay_stat_coverage_count_tasks_rideshare:
          fragment(
            "COALESCE(CEIL(SUM(CASE WHEN ? = ? THEN GREATEST(COALESCE(?,1) * ?, 1) END))::int,0)",
            esc.service_class_id,
            ^@service_class_id_rideshare,
            a.tasks_total,
            ah.percent_of_activity
          ),
        hourly_pay_stat_coverage_count_tasks_delivery:
          fragment(
            "COALESCE(CEIL(SUM(CASE WHEN ? = ? THEN GREATEST(COALESCE(?,1) * ?, 1) END))::int,0)",
            esc.service_class_id,
            ^@service_class_id_delivery,
            a.tasks_total,
            ah.percent_of_activity
          ),
        hourly_pay_stat_coverage_count_tasks_services:
          fragment(
            "COALESCE(CEIL(SUM(CASE WHEN ? = ? THEN GREATEST(COALESCE(?,1) * ?, 1) END))::int,0)",
            esc.service_class_id,
            ^@service_class_id_services,
            a.tasks_total,
            ah.percent_of_activity
          )
      }
    )
    |> Repo.one(timeout: :infinity)
  end

  def query, do: from(stat in AverageHourlyPayStat)

  @doc """
  Queries data captured from the DSC Community insights prior to transition to WAO
  """
  def query_legacy, do: from(stat in AverageHourlyPayStatDSC)

  def query_filter_id(qry, id_or_ids, include \\ true) do
    id_or_ids = List.wrap(id_or_ids)

    if include,
      do: where(qry, [stat], stat.id in ^id_or_ids),
      else: where(qry, [stat], stat.id not in ^id_or_ids)
  end

  def query_filter_metro_area(qry, metro_area_id_or_ids) do
    metro_area_id_or_ids = List.wrap(metro_area_id_or_ids)
    where(qry, [stat], stat.metro_area_id in ^metro_area_id_or_ids)
  end

  def query_filter_employer_service_class(qry, employer_svc_class_id_or_ids) do
    employer_svc_class_id_or_ids = List.wrap(employer_svc_class_id_or_ids)
    where(qry, [stat], stat.employer_service_class_id in ^employer_svc_class_id_or_ids)
  end

  def query_filter_service_class(qry, service_class_id_or_ids) do
    service_class_id_or_ids = List.wrap(service_class_id_or_ids)

    subqry =
      from(esc in EmployerServiceClass)
      |> where([esc], esc.service_class_id in ^service_class_id_or_ids)
      |> select([esc], esc.id)

    where(qry, [stat], stat.employer_service_class_id in subquery(subqry))
  end

  def query_filter_day_of_week(qry, day_or_days) do
    day_or_days = List.wrap(day_or_days)
    where(qry, [stat], stat.day_of_week in ^day_or_days)
  end

  def query_filter_hour_of_day(qry, hour_or_hours) do
    hour_or_hours = List.wrap(hour_or_hours)
    where(qry, [stat], stat.hour_local in ^hour_or_hours)
  end

  def query_filter_week_range(qry, start_week, end_week),
    do: query_filter_week_range(qry, start_week, end_week, true)

  def query_filter_week_range(qry, %Date{} = start_week, nil = _end_week, inclusive) do
    if inclusive,
      do: where(qry, [stat], stat.week_start_date >= ^start_week),
      else: where(qry, [stat], stat.week_start_date > ^start_week)
  end

  def query_filter_week_range(qry, nil = _start_week, %Date{} = end_week, inclusive) do
    if inclusive,
      do: where(qry, [stat], stat.week_start_date <= ^end_week),
      else: where(qry, [stat], stat.week_start_date < ^end_week)
  end

  def query_filter_week_range(qry, %Date{} = start_week, %Date{} = end_week, inclusive) do
    qry
    |> query_filter_week_range(start_week, nil, inclusive)
    |> query_filter_week_range(nil, end_week, inclusive)
  end

  def query_filter_week(qry, week_or_weeks) do
    week_or_weeks = List.wrap(week_or_weeks)
    where(qry, [stat], stat.week_start_date in ^week_or_weeks)
  end

  def delete_outdated_stats do
    most_recent_week =
      query()
      |> select([stat], max(stat.week_start_date))
      |> Repo.one()

    if is_nil(most_recent_week) do
      {:ok, 0}
    else
      oldest_date_to_keep = Date.add(most_recent_week, -@sixteen_weeks)

      {row_count, _} =
        query()
        |> query_filter_week_range(nil, oldest_date_to_keep, false)
        |> Repo.delete_all(timeout: :infinity)

      {:ok, row_count}
    end
  end

  # Given a list of lists of stats, pick the most reliable stat from each group
  defp select_best_stats(stat_grps) do
    Enum.map(stat_grps, fn stat_grp ->
      Enum.sort_by(stat_grp, fn stat -> stat.count_users end, :desc)
      |> Enum.at(0)
    end)
  end

  defp get_summary_data(
         qry,
         metro_area_id,
         employer_service_class_ids,
         service_class_ids
       ) do
    most_recent_week =
      qry
      |> query_filter_metro_area(metro_area_id)
      |> select([stat], max(stat.week_start_date))
      |> Repo.one()

    qry =
      qry
      |> preload(:employer_service_class)
      |> query_filter_metro_area(metro_area_id)
      |> query_filter_week(most_recent_week)

    qry =
      if is_nil(employer_service_class_ids),
        do: qry,
        else: query_filter_employer_service_class(qry, employer_service_class_ids)

    qry =
      if is_nil(service_class_ids),
        do: qry,
        else: query_filter_service_class(qry, service_class_ids)

    {most_recent_week, Repo.all(qry)}
  end

  def get_summary(metro_area_id, employer_service_class_ids \\ nil, service_class_ids \\ nil) do
    {most_recent_week_wao, stats_wao} =
      get_summary_data(
        query(),
        metro_area_id,
        employer_service_class_ids,
        service_class_ids
      )

    {most_recent_week_dsc, stats_dsc} =
      get_summary_data(
        query_legacy(),
        metro_area_id,
        employer_service_class_ids,
        service_class_ids
      )

    current_stats =
      (stats_wao ++ stats_dsc)
      |> Enum.group_by(fn stat ->
        {stat.day_of_week, stat.hour_local, stat.employer_service_class_id}
      end)
      |> Map.values()
      |> select_best_stats()

    stat_grps =
      current_stats
      |> Enum.group_by(fn stat -> {stat.day_of_week, stat.hour_local} end)

    stat_grps
    |> Enum.map(fn {{day_of_week, hour_local}, stats} ->
      weighted_earnings =
        stats
        |> Enum.map(fn x -> x.duration_seconds * x.count_tasks * x.earnings_avg_hr_cents end)
        |> Enum.sum()

      weighted_earnings_with_mileage =
        stats
        |> Enum.map(fn x ->
          x.duration_seconds * x.count_tasks * x.earnings_avg_hr_cents_with_mileage
        end)
        |> Enum.sum()

      weighted_tasks =
        stats
        |> Enum.map(fn x -> x.duration_seconds * x.count_tasks end)
        |> Enum.sum()

      %{
        metro_area_id: metro_area_id,
        week_start_date: most_recent_week_wao || most_recent_week_dsc,
        day_of_week: day_of_week,
        hour_local: hour_local,
        earnings_avg_hr_cents: round(weighted_earnings / weighted_tasks),
        earnings_avg_hr_cents_with_mileage:
          round(weighted_earnings_with_mileage / weighted_tasks),
        best_employer:
          stats
          |> Enum.sort_by(fn x -> x.earnings_avg_hr_cents end, :desc)
          |> Enum.at(0)
          |> Map.take(@best_employer_fields),
        best_employer_with_mileage:
          stats
          |> Enum.sort_by(fn x -> x.earnings_avg_hr_cents_with_mileage end, :desc)
          |> Enum.at(0)
          |> Map.take(@best_employer_fields),
        coverage: %{
          count_employers: Enum.count(stats),
          count_service_classes:
            stats
            |> Enum.map(fn x -> x.employer_service_class.service_class_id end)
            |> Enum.uniq()
            |> Enum.count(),
          count_activities:
            stats
            |> Enum.map(fn x -> x.count_activities end)
            |> Enum.sum(),
          count_tasks:
            stats
            |> Enum.map(fn x -> x.count_tasks end)
            |> Enum.sum(),
          duration_seconds:
            stats
            |> Enum.map(fn x -> x.duration_seconds end)
            |> Enum.sum(),
          earnings_total_cents:
            stats
            |> Enum.map(fn x -> x.earnings_total_cents end)
            |> Enum.sum(),
          deduction_mileage_cents:
            stats
            |> Enum.map(fn x -> x.deduction_mileage_cents end)
            |> Enum.sum(),
          distance_miles:
            stats
            |> Enum.map(fn x -> Decimal.to_float(x.distance_miles || @decimal_zero) end)
            |> Enum.sum()
            |> round()
        }
      }
    end)
  end

  defp get_trend_data(
         qry,
         metro_area_id,
         day_of_week,
         hour_local,
         employer_service_class_ids,
         service_class_ids
       ) do
    qry =
      qry
      |> preload(:employer_service_class)
      |> query_filter_metro_area(metro_area_id)
      |> query_filter_day_of_week(day_of_week)
      |> query_filter_hour_of_day(hour_local)

    qry =
      if is_nil(employer_service_class_ids),
        do: qry,
        else: query_filter_employer_service_class(qry, employer_service_class_ids)

    qry =
      if is_nil(service_class_ids),
        do: qry,
        else: query_filter_service_class(qry, service_class_ids)

    Repo.all(qry)
  end

  def get_trend(
        metro_area_id,
        day_of_week,
        hour_local,
        employer_service_class_ids \\ nil,
        service_class_ids \\ nil
      ) do
    stats_wao =
      get_trend_data(
        query(),
        metro_area_id,
        day_of_week,
        hour_local,
        employer_service_class_ids,
        service_class_ids
      )

    stats_dsc =
      get_trend_data(
        query_legacy(),
        metro_area_id,
        day_of_week,
        hour_local,
        employer_service_class_ids,
        service_class_ids
      )

    stats =
      (stats_wao ++ stats_dsc)
      |> Enum.group_by(fn stat ->
        {stat.week_start_date, stat.day_of_week, stat.hour_local, stat.employer_service_class_id}
      end)
      |> Map.values()
      |> select_best_stats()

    Enum.map(stats, fn stat ->
      stat
      |> Map.take(@trend_fields)
      |> Map.put(:service_class_id, stat.employer_service_class.service_class_id)
    end)
  end
end
