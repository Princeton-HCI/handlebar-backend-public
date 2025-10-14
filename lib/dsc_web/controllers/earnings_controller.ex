defmodule DriversSeatCoopWeb.EarningsController do
  use DriversSeatCoopWeb, :controller
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Activities
  alias DriversSeatCoop.Earnings
  alias DriversSeatCoop.Earnings.Oban.ExportUserEarningsQuery
  alias DriversSeatCoop.Util.DateTimeUtil

  def summary_latest(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.summary_latest(params) do
      user = conn.assigns.user
      user_id = user.id
      summary_level = Map.get(params, :level)

      timezone = User.timezone(user)

      today = DateTimeUtil.datetime_to_working_day(DateTime.utc_now(), timezone)

      [_min_timespan_date, max_timespan_date] = Earnings.get_timespan_date_range(user_id)
      [_min_activity_date, max_activity_date] = Activities.get_activity_date_range(user_id)

      dates = List.wrap(max_activity_date) ++ List.wrap(max_timespan_date)

      max_date =
        if Enum.empty?(dates),
          do: today,
          else: Enum.min([today, Enum.max(dates, Date)], Date)

      {work_date_start, work_date_end} =
        DateTimeUtil.get_time_window_for_date(max_date, summary_level)

      get_earnings_summary(conn, work_date_start, work_date_end)
    end
  end

  def summary(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.index(params) do
      work_date_start = Map.get(params, :work_date_start)
      work_date_end = Map.get(params, :work_date_end)
      get_earnings_summary(conn, work_date_start, work_date_end)
    end
  end

  defp get_earnings_summary(conn, work_date_start, work_date_end) do
    user_id = conn.assigns.user.id

    time_and_mileage =
      Earnings.get_overall_time_and_mileage_summary(
        user_id,
        "user_facing",
        work_date_start,
        work_date_end,
        nil
      )
      |> Enum.at(0)

    job_earnings =
      Earnings.get_job_earnings_summary(
        user_id,
        "user_facing",
        work_date_start,
        work_date_end,
        nil,
        "employer"
      )

    other_earnings =
      Earnings.get_other_earnings_summary(
        user_id,
        work_date_start,
        work_date_end,
        nil,
        "employer"
      )

    render(conn, "summary.json",
      data: %{
        work_date_start: work_date_start,
        work_date_end: work_date_end,
        time_and_mileage: time_and_mileage,
        job_earnings: job_earnings,
        other_earnings: other_earnings
      }
    )
  end

  def detail(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.detail(params) do
      timespans =
        Earnings.get_timespan_details(
          conn.assigns.user.id,
          "user_facing",
          Map.get(params, :work_date),
          Map.get(params, :work_date)
        )

      render(conn, "detail.json", %{timespans: timespans})
    end
  end

  def index(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.index(params) do
      user_id = conn.assigns.user.id
      work_date_start = Map.get(params, :work_date_start)
      work_date_end = Map.get(params, :work_date_end)
      time_grouping = Map.get(params, :time_grouping)

      time_and_mileage =
        Earnings.get_overall_time_and_mileage_summary(
          user_id,
          "user_facing",
          work_date_start,
          work_date_end,
          time_grouping
        )

      job_earnings =
        Earnings.get_job_earnings_summary(
          user_id,
          "user_facing",
          work_date_start,
          work_date_end,
          time_grouping,
          nil
        )

      other_earnings =
        Earnings.get_other_earnings_summary(
          user_id,
          work_date_start,
          work_date_end,
          time_grouping,
          nil
        )

      render(conn, "index.json", %{
        time_grouping: time_grouping,
        time_and_mileage: time_and_mileage,
        job_earnings: job_earnings,
        other_earnings: other_earnings
      })
    end
  end

  def activity(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.activity(params) do
      user_id = conn.assigns.user.id
      activity_id = Map.get(params, :activity_id)

      activity = Activities.get_activity(user_id, activity_id)

      render(conn, "activity.json", %{
        activity: activity
      })
    end
  end

  def activity_index(conn, params) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.activity_index(params) do
      user_id = conn.assigns.user.id

      activities = Activities.get_activities(user_id, params)

      render(conn, "activities.json", %{
        activities: activities
      })
    end
  end

  def export(conn, %{"query" => params}) do
    with {:ok, params} <- DriversSeatCoopWeb.EarningsValidator.export(params) do
      user = conn.assigns.user

      with {:ok, _} <-
             ExportUserEarningsQuery.schedule_job(user.id, params) do
        send_resp(conn, :no_content, "")
      end
    end
  end
end
