defmodule DriversSeatCoop.Goals do
  import Ecto.Query, warn: false
  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Earnings
  alias DriversSeatCoop.Goals.Goal
  alias DriversSeatCoop.Goals.GoalMeasurement
  alias DriversSeatCoop.Goals.Oban.CalculatePerformanceForUserWindow
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Util.DateTimeUtil
  alias DriversSeatCoop.Util.MapUtil

  @sub_frequency_default "all"

  @additional_info_template %{
    count_activities: 0,
    count_jobs: 0,
    count_tasks: 0,
    count_work_days: 0,
    earnings_pay_cents: 0,
    earnings_tip_cents: 0,
    earnings_bonus_cents: 0,
    earnings_total_cents: 0,
    duration_seconds: 0,
    duration_seconds_engaged: 0,
    selected_miles: Decimal.new(0),
    selected_miles_engaged: Decimal.new(0)
  }

  @doc """
  This is in the minimum version in which the goals feature
  is available
  """
  def get_goals(user_id, frequency) do
    query_goals()
    |> query_goals_filter_user(user_id)
    |> query_goals_filter_frequency(frequency)
    |> Repo.all()
  end

  def query_goals, do: from(goal in Goal)

  def query_goals_filter_user(qry, user_id_or_ids) do
    user_id_or_ids = List.wrap(user_id_or_ids)
    where(qry, [g], g.user_id in ^user_id_or_ids)
  end

  def query_goals_filter_type(qry, goal_type) do
    goal_type = "#{goal_type}"

    from(goal in qry,
      where: goal.type == ^goal_type
    )
  end

  def query_goals_filter_frequency(qry, frequency) do
    frequency = "#{frequency}"

    from(goal in qry,
      where: goal.frequency == ^frequency
    )
  end

  def query_goals_filter_start_date(qry, start_date) do
    start_date =
      start_date
      |> List.wrap()
      |> Enum.uniq()

    from(goal in qry,
      where: goal.start_date in ^start_date
    )
  end

  def update_goals(user_id, type, frequency, start_date, sub_goals, replace_date)
      when is_map(sub_goals) do
    type = String.to_atom("#{type}")
    frequency = String.to_atom("#{frequency}")

    affected_dates = [start_date, replace_date || start_date]

    existing_goals =
      query_goals()
      |> query_goals_filter_user(user_id)
      |> query_goals_filter_type(type)
      |> query_goals_filter_frequency(frequency)
      |> query_goals_filter_start_date(affected_dates)
      |> Repo.all()

    # normalize the date supplied in case it is incorrect
    {start_date, _end_date} = DateTimeUtil.get_time_window_for_date(start_date, frequency)

    attr_template = %{
      type: type,
      frequency: frequency,
      start_date: start_date
    }

    multi = Ecto.Multi.new()

    {multi, goals_to_delete} =
      sub_goals
      |> Enum.to_list()
      |> Enum.filter(fn {_sub_frequency, goal_amount} ->
        not is_nil(goal_amount) and goal_amount > 0
      end)
      |> Enum.reduce({multi, existing_goals}, fn {sub_frequency, goal_amount},
                                                 {m, remaining_goals} ->
        attrs =
          attr_template
          |> Map.put(:amount, goal_amount)
          |> Map.put(:sub_frequency, sub_frequency)

        goal =
          Enum.find(remaining_goals, fn g ->
            Date.compare(g.start_date, start_date) == :eq and g.sub_frequency == sub_frequency
          end) ||
            Enum.find(remaining_goals, fn g -> g.sub_frequency == sub_frequency end) ||
            %Goal{user_id: user_id}

        changeset = Goal.changeset(goal, attrs)

        remaining_goals = Enum.reject(remaining_goals, fn g -> g == goal end)

        m =
          Ecto.Multi.insert_or_update(m, sub_frequency, changeset,
            on_conflict: {:replace, [:amount, :updated_at]},
            conflict_target: [:user_id, :type, :frequency, :start_date, :sub_frequency]
          )

        {m, remaining_goals}
      end)

    goal_ids_to_delete =
      goals_to_delete
      |> Enum.map(fn g -> g.id end)

    multi = delete_goals_by_id(multi, user_id, goal_ids_to_delete)

    with {:ok, result} <- Repo.transaction(multi) do
      schedule_goal_performance_updates(user_id, type, frequency, affected_dates)
      {:ok, result}
    end
  end

  def delete_goals(user_id, type, frequency, start_date) do
    type = String.to_atom("#{type}")
    frequency = String.to_atom("#{frequency}")

    qry =
      query_goals()
      |> query_goals_filter_user(user_id)
      |> query_goals_filter_type(type)
      |> query_goals_filter_frequency(frequency)
      |> query_goals_filter_start_date(start_date)

    goal_ids_to_delete =
      from(goal in qry, select: goal.id)
      |> Repo.all()

    multi = Ecto.Multi.new()

    multi = delete_goals_by_id(multi, user_id, goal_ids_to_delete)

    with {:ok, result} <- Repo.transaction(multi) do
      schedule_goal_performance_updates(user_id, type, frequency, start_date)
      {:ok, result}
    end
  end

  def schedule_goal_performance_updates(user_id, type, frequency, date_or_dates) do
    user = Accounts.get_user!(user_id)
    today = DateTimeUtil.datetime_to_working_day(DateTime.utc_now(), User.timezone(user))
    type = String.to_atom("#{type}")
    frequency = String.to_atom("#{frequency}")

    qry =
      query_goals()
      |> query_goals_filter_user(user_id)
      |> query_goals_filter_type(type)
      |> query_goals_filter_frequency(frequency)

    goal_dates =
      from(g in qry,
        select: g.start_date,
        order_by: [g.start_date]
      )
      |> Repo.all()

    List.wrap(date_or_dates)
    |> Enum.uniq()
    |> Enum.flat_map(fn d ->
      next_goal_date =
        Enum.find(goal_dates, today, fn goal_date -> Date.compare(goal_date, d) == :gt end)

      DateTimeUtil.get_time_windows_for_range(d, next_goal_date, frequency)
    end)
    |> Enum.uniq()
    |> Enum.each(fn {start_date, _end_date} ->
      CalculatePerformanceForUserWindow.schedule_job(user.id, type, frequency, start_date)
    end)
  end

  def update_goal_performance(
        user_id,
        type,
        frequency,
        %Date{} = window_date
      ) do
    type = String.to_atom("#{type}")
    frequency = String.to_atom("#{frequency}")

    del_qry =
      from(meas in GoalMeasurement,
        join: goal in Goal,
        on: goal.id == meas.goal_id and goal.user_id == meas.user_id,
        where: goal.user_id == ^user_id,
        where: goal.type == ^type,
        where: goal.frequency == ^frequency,
        where: meas.window_date == ^window_date
      )

    multi = Ecto.Multi.new()

    multi =
      case calculate_goal_performance(user_id, type, frequency, window_date) do
        {:ok, performance, goal} ->
          changeset =
            GoalMeasurement.changeset(
              %GoalMeasurement{user_id: goal.user_id, goal_id: goal.id},
              performance
            )

          del_qry =
            del_qry
            |> where([goal], goal.id != ^goal.id)

          multi
          |> Ecto.Multi.delete_all("delete", del_qry)
          |> Ecto.Multi.insert("insert", changeset,
            on_conflict: {:replace_all_except, [:id, :inserted_at]},
            conflict_target: [:goal_id, :window_date]
          )

        _ ->
          Ecto.Multi.delete_all(multi, "delete", del_qry)
      end

    Repo.transaction(multi)
  end

  def calculate_goal_performance(
        user_id,
        type,
        frequency,
        %Date{} = window_date
      ) do
    user = Accounts.get_user!(user_id)
    today = DateTimeUtil.datetime_to_working_day(DateTime.utc_now(), User.timezone(user))

    # use the date to identify the performance window.
    {window_start, window_end} = DateTimeUtil.get_time_window_for_date(window_date, frequency)

    qry =
      query_goals()
      |> query_goals_filter_user(user_id)
      |> query_goals_filter_type(type)
      |> query_goals_filter_frequency(frequency)
      |> where([goal], goal.start_date <= ^window_start)
      |> order_by([goal], desc: goal.start_date)

    goal =
      if frequency != :day do
        qry
        |> limit(1)
        |> Repo.one()
      else
        # Find the first Start_on and use it to filter for the specific day
        goals =
          qry
          |> Repo.all()

        first_goal = Enum.at(goals, 0)

        if is_nil(first_goal) do
          nil
        else
          day_number = DateTimeUtil.day_index(window_start)

          goals
          |> Enum.filter(fn goal ->
            Date.compare(goal.start_date, first_goal.start_date) == :eq
          end)
          |> Enum.find(fn goal ->
            goal.sub_frequency in [@sub_frequency_default, "#{day_number}"]
          end)
        end
      end

    cond do
      is_nil(goal) ->
        {:not_calculated, :no_goal_available}

      Date.compare(window_start, today) == :gt ->
        {:not_calculated, :window_in_future, goal}

      goal.amount <= 0 or is_nil(goal.amount) ->
        {:not_calculated, :invalid_goal, goal}

      true ->
        calculate_goal_performance_impl(user, goal, window_start, window_end)
    end
  end

  def query_performance do
    from(meas in GoalMeasurement,
      join: goal in Goal,
      on: goal.id == meas.goal_id and goal.user_id == meas.user_id
    )
  end

  def query_performance_filter_user(qry, user_id_or_ids) do
    user_id_or_ids = List.wrap(user_id_or_ids)
    where(qry, [meas, goal], goal.user_id in ^user_id_or_ids)
  end

  def query_performance_filter_frequency(qry, frequency_or_frequencies) do
    frequency_or_frequencies = List.wrap(frequency_or_frequencies)
    where(qry, [meas, goal], goal.frequency in ^frequency_or_frequencies)
  end

  def query_performance_filter_type(qry, goal_type_or_types) do
    goal_type_or_types = List.wrap(goal_type_or_types)
    where(qry, [meas, goal], goal.type in ^goal_type_or_types)
  end

  def query_performance_filter_performance_date(qry, frequency, date_or_dates) do
    dates =
      List.wrap(date_or_dates)
      |> Enum.map(fn window_date ->
        DateTimeUtil.get_time_window_for_date(window_date, frequency)
      end)
      |> Enum.map(fn {start_date, _end_date} -> start_date end)
      |> Enum.uniq()

    qry
    |> where([meas, goal], goal.frequency == ^frequency)
    |> where([meas, goal], meas.window_date in ^dates)
  end

  def query_performance_filter_performance_date_range(qry, nil, nil), do: qry

  def query_performance_filter_performance_date_range(qry, %Date{} = date_min, nil),
    do: where(qry, [meas, goal], meas.window_date >= ^date_min)

  def query_performance_filter_performance_date_range(qry, nil, %Date{} = date_max),
    do: where(qry, [meas, goal], meas.window_date <= ^date_max)

  def query_performance_filter_performance_date_range(qry, %Date{} = date_min, %Date{} = date_max) do
    qry
    |> query_performance_filter_performance_date_range(date_min, nil)
    |> query_performance_filter_performance_date_range(nil, date_max)
  end

  def query_performance_filter_performance_percent(qry, nil = _percent_min, nil = _percent_max),
    do: qry

  def query_performance_filter_performance_percent(qry, nil = _percent_min, percent_max),
    do: where(qry, [meas, goal], meas.performance_percent <= ^percent_max)

  def query_performance_filter_performance_percent(qry, percent_min, nil = _percent_max),
    do: where(qry, [meas, goal], meas.performance_percent >= ^percent_min)

  def query_performance_filter_performance_percent(qry, percent_min, percent_max) do
    qry
    |> query_performance_filter_performance_percent(percent_min, nil)
    |> query_performance_filter_performance_percent(nil, percent_max)
  end

  def get_goal_performance(user_id, frequency, date_or_dates) do
    query_performance()
    |> query_performance_filter_user(user_id)
    |> query_performance_filter_performance_date(frequency, date_or_dates)
    |> select([meas, goal], {meas, goal})
    |> Repo.all()
  end

  defp calculate_goal_performance_impl(
         %User{} = user,
         %Goal{} = goal,
         %Date{} = window_start,
         %Date{} = window_end
       ) do
    work_time =
      Earnings.get_overall_time_and_mileage_summary(
        user.id,
        "user_facing",
        window_start,
        window_end
      )
      |> Enum.at(0, %{})

    job_earnings =
      Earnings.get_job_earnings_summary(user.id, "user_facing", window_start, window_end)
      |> Enum.at(0, %{})

    other_earnings =
      Earnings.get_other_earnings_summary(user.id, window_start, window_end)
      |> Enum.at(0, %{})

    earnings = combine_job_and_other_earnings(job_earnings, other_earnings)

    if (Map.get(earnings, :earnings_total_cents) || 0) == 0 and
         (Map.get(work_time, :duration_seconds) || 0) == 0 do
      {:not_calculated, :did_not_work, goal}
    else
      work_time =
        Map.take(work_time || %{}, [
          :count_work_days,
          :duration_seconds,
          :duration_seconds_engaged,
          :selected_miles,
          :selected_miles_engaged
        ])

      additional_info =
        @additional_info_template
        |> Map.merge(earnings)
        |> Map.merge(work_time)

      performance = %{
        performance_amount: additional_info.earnings_total_cents || 0,
        performance_percent:
          ((additional_info.earnings_total_cents || 0) / goal.amount)
          |> Decimal.from_float()
          |> Decimal.round(2),
        window_date: window_start,
        additional_info: additional_info
      }

      {:ok, performance, goal}
    end
  end

  defp combine_job_and_other_earnings(job_earnings, other_earnings) do
    job_earnings = job_earnings || %{}
    other_earnings = other_earnings || %{}

    %{
      earnings_pay_cents:
        MapUtil.get_value_or_default(job_earnings, :job_earnings_pay_cents, 0) +
          MapUtil.get_value_or_default(other_earnings, :other_earnings_pay_cents, 0),
      earnings_tip_cents:
        MapUtil.get_value_or_default(job_earnings, :job_earnings_tip_cents, 0) +
          MapUtil.get_value_or_default(other_earnings, :other_earnings_tip_cents, 0),
      earnings_bonus_cents:
        MapUtil.get_value_or_default(job_earnings, :job_earnings_bonus_cents, 0) +
          MapUtil.get_value_or_default(other_earnings, :other_earnings_bonus_cents, 0),
      earnings_total_cents:
        MapUtil.get_value_or_default(job_earnings, :job_earnings_total_cents, 0) +
          MapUtil.get_value_or_default(other_earnings, :other_earnings_total_cents, 0),
      count_activities:
        MapUtil.get_value_or_default(job_earnings, :job_count, 0) +
          MapUtil.get_value_or_default(other_earnings, :other_count_activities, 0),
      count_jobs:
        MapUtil.get_value_or_default(job_earnings, :job_count_tasks, 0) +
          MapUtil.get_value_or_default(other_earnings, :other_count_activities, 0),
      count_work_days: Map.get(job_earnings, :job_count_days) || 0
    }
  end

  defp delete_goals_by_id(multi, user_id, goal_ids) do
    goal_ids = List.wrap(goal_ids)

    qry =
      from(gm in GoalMeasurement,
        where: gm.user_id == ^user_id,
        where: gm.goal_id in ^goal_ids
      )

    multi = Ecto.Multi.delete_all(multi, "delete goal measurements", qry)

    qry =
      from(goal in Goal,
        where: goal.user_id == ^user_id,
        where: goal.id in ^goal_ids
      )

    Ecto.Multi.delete_all(multi, "delete goals", qry)
  end
end
