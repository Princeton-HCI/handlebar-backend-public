defmodule DriversSeatCoop.ScheduledShifts.Oban.SendStartShiftReminder do
  @moduledoc """
  This job will send a reminder to the user to start their shift based on their
  scheduled shifts.
  """

  use Oban.Worker,
    queue: :shift_reminders,
    unique: [period: :infinity, states: [:available, :scheduled, :executing], keys: [:user_id]],
    max_attempts: 3

  require Logger
  alias DriversSeatCoop.{Accounts, Shifts}

  def schedule_job(
        user_id,
        shift_start_time_local,
        %DateTime{
          time_zone: "Etc/UTC"
        } = scheduled_at_utc
      ) do
    new(%{user_id: user_id, shift_start_time_local: shift_start_time_local},
      scheduled_at: scheduled_at_utc,
      replace: [:scheduled_at, :args]
    )
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{"user_id" => user_id, "shift_start_time_local" => shift_start_time_local}
      }) do
    Logger.metadata(oban_job_id: id)

    Logger.info(
      "Processing start shift reminder for #{user_id} for shift starting at #{shift_start_time_local}"
    )

    user = Accounts.get_user!(user_id)
    is_on_shift = Shifts.is_user_currently_on_shift(user.id)
    send_reminder!(user, shift_start_time_local, is_on_shift)
  end

  # Reminder is sent because user is not on shift and they can receive notification
  defp send_reminder!(user, shift_start_time_local, false) do
    # OneSignal notifications disabled
    Logger.info("Start shift reminder skipped (notifications disabled) for user #{user.id}")
    {:ok, :notifications_disabled}
  end

  # Reminder not needed because user is currently on-shift
  defp send_reminder!(user, shift_start_time_local, true) do
    Logger.info(
      "Start shift reminder skipped (already on shift) for user #{user.id} for shift starting at #{shift_start_time_local}"
    )
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)
end
