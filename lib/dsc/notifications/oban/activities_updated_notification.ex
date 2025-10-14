defmodule DriversSeatCoop.Notifications.Oban.ActivitiesUpdatedNotification do
  @moduledoc """
  Job handles a single users's Activities Updated Notification.
  Based on their experiment group, determines if the user should recieve a notification.
  If so, sends it out.
  """

  import Ecto.Query, warn: false

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Activities
  alias DriversSeatCoop.Repo

  @max_count_notif 5

  use Oban.Worker,
    queue: :notifications,
    unique: [
      period: :infinity,
      states: [:available, :scheduled],
      keys: [:user_id]
    ],
    max_attempts: 3

  require Logger

  def schedule_jobs do
    users =
      Accounts.get_users_query()
      |> Accounts.filter_users_push_notification_status(true)
      |> Accounts.filter_include_users_with_activities_require_notification()
      |> Repo.all()

    users
    |> Enum.each(fn u -> schedule_job(u.id) end)

    :ok
  end

  def schedule_job(user_id) do
    Oban.insert(new(%{user_id: user_id}))
    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{"user_id" => user_id}
      }) do
    Logger.metadata(oban_job_id: id)

    Logger.info("Processing Activities Updated Notification Request for user #{user_id}")

    user = DriversSeatCoop.Accounts.get_user!(user_id)

    case determine_activity_notification_action(user) do
      {:do_not_send, _reason} ->
        {:ok, :not_sent}

      {:error, reason} ->
        {:error, reason}

      {:send, activities} ->
        send_notification_for_activities(user, activities)
        {:ok, :sent}
    end
  end

  def determine_activity_notification_action(%User{} = user) do
    if User.can_receive_notification(user) do
      determine_activity_notification_action(user, 3)
    else
      {:do_not_send, :user_opted_out_of_push_notifications}
    end
  end

  # Determine what to do based on activities, last app usage, last notification and
  # number of days between notifications.
  def determine_activity_notification_action(%User{} = user, number_of_days) do
    last_app_usage = Accounts.get_last_action_date(user.id, [:login, :session_refresh])

    last_app_usage =
      if is_nil(last_app_usage) do
        DateTime.from_naive!(user.inserted_at, "Etc/UTC")
      else
        DateTime.from_naive!(last_app_usage, "Etc/UTC")
      end

    notif_dates =
      Activities.get_activity_notif_counts_by_date(user.id)
      |> Enum.map(fn stat -> stat.notified_on end)

    determine_activity_notification_action(user, number_of_days, last_app_usage, notif_dates)
  end

  # If the user has never been notified of their activities, get all activities since their
  # last app usage and send them a notification.  For new users, this will get all of their activities
  # for their initial argyle sync
  def determine_activity_notification_action(
        %User{} = user,
        _number_of_days,
        _last_app_usage,
        [] = _notif_dates
      ) do
    {:send,
     Activities.get_activities_query(user.id)
     |> Activities.filter_activities_require_notification()
     |> Repo.all()}
  end

  # If the user has been notified, identify activities since their last usage and/or notification
  # and send those to them.
  def determine_activity_notification_action(
        %User{} = user,
        number_of_days,
        last_app_usage,
        notif_dates_all
      ) do
    now = DateTime.utc_now()

    last_notif_date = Enum.max(notif_dates_all, DateTime)

    count_notif_since_last_usage =
      Enum.count(notif_dates_all, fn d -> DateTime.compare(d, last_app_usage) == :gt end)

    cond do
      # Since the user has received x notifications since their last usage, assume that
      # they are no longer using the app and stop sending notifications
      count_notif_since_last_usage >= @max_count_notif ->
        {:do_not_send, :exceeded_notification_count_without_app_usage}

      # If it has been less than x days since the user last used the app, no need to notify
      DateTime.diff(now, last_app_usage, :day) < number_of_days ->
        {:do_not_send, :too_soon_since_last_usage}

      # It it has been less than x days since they have received their last notification
      DateTime.diff(now, last_notif_date, :day) < number_of_days ->
        {:do_not_send, :too_soon_since_last_notification}

      # otherwise get the activities
      true ->
        since_date = Enum.max([last_app_usage, last_notif_date])

        {:send,
         Activities.get_activities_query(user.id)
         |> Activities.filter_activities_require_notification()
         |> Activities.filter_activities_update_date(since_date, nil)
         |> Repo.all()}
    end
  end

  defp send_notification_for_activities(_user, [] = _activities) do
    {:ok, :not_sent, :no_activities_available}
  end

  defp send_notification_for_activities(user, activities) do
    # OneSignal notifications disabled
    activity_ids = Enum.map(activities, fn a -> a.id end)
    Activities.update_notification_sent(activity_ids)
    {:ok, :notifications_disabled, activity_ids}
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)
end
