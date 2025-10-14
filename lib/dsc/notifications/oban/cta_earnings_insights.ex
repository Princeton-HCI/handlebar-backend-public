defmodule DriversSeatCoop.Notifications.Oban.CTAEarningsInsights do
  @moduledoc """
  This job will send an engagement push notification to users 24-hours after signing up.
  """

  import Ecto.Query, warn: false

  use Oban.Worker,
    queue: :notifications,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing, :completed],
      keys: [:user_id]
    ],
    max_attempts: 3

  require Logger

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Repo

  @cutoff_date ~N[2023-04-06 07:00:00.000000]
  @schedule_future_minutes 60 * 24

  def schedule_job(%User{} = user) do
    cond do
      NaiveDateTime.compare(user.inserted_at, @cutoff_date) == :lt ->
        {:ok, :not_scheduled_user_existed_before_CTA}

      not User.has_profile?(user) ->
        {:ok, :not_scheduled_profile_incomplete}

      true ->
        scheduled_at_utc =
          DateTime.utc_now()
          |> DateTime.add(@schedule_future_minutes, :minute)

        new(%{user_id: user.id},
          scheduled_at: scheduled_at_utc,
          replace: []
        )
        |> Oban.insert()
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "user_id" => user_id
        }
      }) do
    Logger.metadata(oban_job_id: id)

    Logger.info("Processing CTA - Welcome to Earnings Insights for #{user_id}")

    user = Accounts.get_user!(user_id)

    cond do
      # user is deleted
      user.deleted ->
        {:ok, :not_sent_user_deleted}

      # not able to receive notifications (opted out)
      not User.can_receive_notification(user) ->
        {:ok, :not_sent_notifications_not_enabled_for_user}

      true ->
        send_notification(user)
    end
  end

  defp send_notification(user) do
    count_users_with_earnings =
      from(u in Accounts.get_users_with_earnings_query(),
        select: count()
      )
      |> Repo.one()

    # OneSignal notifications disabled
    {:ok, :notifications_disabled}
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)
end
