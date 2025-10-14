defmodule DriversSeatCoop.Notifications.Oban.GoalPerformanceUpdate do
  @moduledoc """
  Responsible for sending progress update message to users for weekly and monthly goals.
  """

  import Ecto.Query, warn: false

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Logger

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Goals
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Util.DateTimeUtil

  def schedule_jobs(id, frequency) do
    Logger.metadata(oban_job_id: id)

    measurements = get_qualified_measurements(frequency)

    Logger.info(
      "Identified #{Enum.count(measurements)} #{frequency} qualified performance measurements"
    )

    Enum.each(measurements, fn meas -> Oban.insert(new(meas)) end)

    :ok
  end

  def get_qualified_measurements(frequency) do
    today = Date.utc_today()
    {start_window, _end_window} = DateTimeUtil.get_time_window_for_date(today, frequency)

    Goals.query_performance()
    |> Goals.query_performance_filter_type(:earnings)
    |> Goals.query_performance_filter_performance_date(frequency, start_window)
    |> Goals.query_performance_filter_performance_percent(0.05, 0.99)
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

  # sends the actual email if the user is qualified
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

    Logger.info(
      "Sending Goal Celebration for user #{user_id} for #{goal_frequency} #{window_date} at #{performance_percent} or goal #{goal_amount_cents}"
    )

    window_date = Date.from_iso8601!(window_date)
    user = Accounts.get_user!(user_id)

    cond do
      # user is deleted
      user.deleted ->
        {:ok, :not_sent_user_deleted}

      # not able to receive notifications (opted out)
      not User.can_receive_notification(user) ->
        {:ok, :not_sent_notifications_not_enabled_for_user}

      performance_percent < 0.05 ->
        {:ok, :less_than_5_percent}

      performance_percent >= 1 ->
        {:ok, :greater_than_or_equal_to_100_percent}

      true ->
        # OneSignal notifications disabled
        {:ok, :notifications_disabled}
    end
  end

  # Identifies the population of users based on weekly goals
  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "freq" => "week"
        }
      }),
      do: schedule_jobs(id, :week)

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "freq" => "month"
        }
      }),
      do: schedule_jobs(id, :month)

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)
end
