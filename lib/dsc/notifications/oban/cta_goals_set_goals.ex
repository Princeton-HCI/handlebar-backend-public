defmodule DriversSeatCoop.Notifications.Oban.CTAGoalsSetGoals do
  @moduledoc """
  This job will send a 1-time engagement push notification to users that are interested in goals and have earnings, but but have not
  created them.
  """

  import Ecto.Query, warn: false

  use Oban.Worker,
    queue: :notifications,
    unique: [
      period: :infinity,
      keys: [:user_id]
    ],
    max_attempts: 3

  require Logger

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Marketing
  alias DriversSeatCoop.OneSignal
  alias DriversSeatCoop.Repo

  def schedule_jobs do
    user_ids_interested_qry =
      Marketing.query_campaign_participation()
      |> Marketing.query_filter_campaign("goals_survey")
      |> Marketing.query_filter_dismissed(false)
      |> Marketing.query_filter_accepted(false)
      |> select([cp], cp.user_id)

    included_users =
      Accounts.get_users_query()
      |> where([u], u.id in subquery(user_ids_interested_qry))
      |> Accounts.filter_include_users_with_earnings_query()
      |> Accounts.filter_include_users_without_earnings_goals_query()
      |> select([u], u.id)
      |> Repo.all()

    Enum.each(included_users, fn u -> schedule_job(u) end)
  end

  def schedule_job(user_id) do
    new(%{user_id: user_id})
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "user_id" => user_id
        }
      }) do
    Logger.metadata(oban_job_id: id)

    Logger.info("Processing CTA - Goals - Set Goals #{user_id}")

    is_still_interested =
      Marketing.query_campaign_participation()
      |> Marketing.query_filter_campaign("goals_survey")
      |> Marketing.query_filter_dismissed(false)
      |> Marketing.query_filter_user(user_id)
      |> Repo.exists?()

    user =
      Accounts.get_users_query()
      |> Accounts.filter_include_users_with_earnings_query()
      |> Accounts.filter_include_users_without_earnings_goals_query()
      |> Accounts.filter_by_user_id_query(user_id)
      |> Repo.one()

    cond do
      # user is not qualified
      is_nil(user) or not is_still_interested ->
        {:ok, :not_sent_user_not_qualified}

      # user is deleted
      user.deleted ->
        {:ok, :not_sent_user_deleted}

      # not able to receive notifications (opted out)
      not User.can_receive_notification(user) ->
        {:ok, :not_sent_notifications_not_enabled_for_user}

      true ->
        OneSignal.send_notification_goals_set_goals(user)
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)
end
