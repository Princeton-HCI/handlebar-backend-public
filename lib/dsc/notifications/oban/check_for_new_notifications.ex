defmodule DriversSeatCoop.Notifications.Oban.CheckForNewNotifications do
  @moduledoc """
  This job will run every hour and is responsible for scheduling any new
  notifications for users.
  """

  import Ecto.Query, warn: false

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Logger

  alias DriversSeatCoop.Notifications.Oban.ActivitiesUpdatedNotification
  alias DriversSeatCoop.Notifications.Oban.CTAGoalsCheckProgress
  alias DriversSeatCoop.Notifications.Oban.GoalPerformanceCelebration

  def schedule_job do
    Oban.insert(new(%{}))
    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id
      }) do
    Logger.metadata(oban_job_id: id)
    Logger.info("Processing Timed Notifications")

    ActivitiesUpdatedNotification.schedule_jobs()
    CTAGoalsCheckProgress.schedule_jobs()
    GoalPerformanceCelebration.schedule_jobs()
    :ok
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)
end
