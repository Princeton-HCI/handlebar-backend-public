defmodule DriversSeatCoop.Notifications.Oban.GoalPerformanceCelebration do
  @moduledoc """
  Responsible for sending out celebration messages to users when they have met or exceeded their goal
  """

  import Ecto.Query, warn: false

  use Oban.Worker,
    queue: :notifications,
    unique: [
      period: :infinity,
      keys: [:user_id, :type, :frequency, :window_date]
    ],
    max_attempts: 3

  require Logger

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Goals
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Util.DateTimeUtil

  def schedule_jobs do
    schedule_jobs(:day, 5)
    schedule_jobs(:week, 2)
    schedule_jobs(:month, 2)
    :ok
  end

  def schedule_jobs(frequency, count) do
    measurements = get_qualified_measurements(frequency, count)

    Logger.info(
      "Identified #{Enum.count(measurements)} #{frequency} qualified performance measurements."
    )

    Enum.each(measurements, fn meas -> Oban.insert(new(meas)) end)

    :ok
  end

  def get_qualified_measurements(frequency, count) do
    today = Date.utc_today()

    performance_windows = get_performance_windows(frequency, today, count)

    dates = Enum.map(performance_windows, fn {window_start, _} -> window_start end)

    Goals.query_performance()
    |> Goals.query_performance_filter_type(:earnings)
    |> Goals.query_performance_filter_performance_date(frequency, dates)
    |> Goals.query_performance_filter_performance_percent(1, nil)
    |> select([meas, goal], %{
      user_id: meas.user_id,
      type: goal.type,
      frequency: goal.frequency,
      window_date: meas.window_date,
      goal_amount_cents: goal.amount,
      performance_percent: meas.performance_percent,
      performance_amount_cents: meas.performance_amount
    })
    |> Repo.all()
    |> Enum.map(fn p -> Map.update!(p, :performance_percent, fn v -> Decimal.to_float(v) end) end)
  end

  defp get_performance_windows(frequency, date, count) do
    {start_date, end_date} = DateTimeUtil.get_time_window_for_date(date, frequency)

    if count > 1 do
      [{start_date, end_date}] ++
        get_performance_windows(frequency, Date.add(start_date, -1), count - 1)
    else
      [{start_date, end_date}]
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "user_id" => user_id,
          "type" => _goal_type,
          "frequency" => goal_frequency,
          "window_date" => window_date,
          "goal_amount_cents" => goal_amount_cents,
          "performance_percent" => performance_percent,
          "performance_amount_cents" => performance_amount_cents
        }
      }) do
    Logger.metadata(oban_job_id: id)

    user = Accounts.get_user!(user_id)
    window_date = Date.from_iso8601!(window_date)

    Logger.info(
      "Sending Goal Performance Update for user #{user_id} for #{goal_frequency} #{window_date} at #{performance_percent} or goal #{goal_amount_cents}"
    )

    cond do
      # user is deleted
      user.deleted ->
        {:ok, :not_sent_user_deleted}

      # not able to receive notifications (opted out)
      not User.can_receive_notification(user) ->
        {:ok, :not_sent_notifications_not_enabled_for_user}

      performance_percent < 1 ->
        {:ok, :less_than_100_percent}

      true ->
        # OneSignal notifications disabled
        {:ok, :notifications_disabled}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{id: id}) do
    Logger.metadata(oban_job_id: id)

    schedule_jobs()
    :ok
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)
end
