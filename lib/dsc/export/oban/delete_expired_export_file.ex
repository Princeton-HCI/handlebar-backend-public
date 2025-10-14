defmodule DriversSeatCoop.Export.Oban.DeleteExpiredExportFile do
  @moduledoc """
  This job will delete a user earnings file after it is no longer downloadable
  using the expiring link provided to user
  """

  use Oban.Worker,
    queue: :user_export_request,
    max_attempts: 3

  require Logger

  def schedule_job(file_id, file_name, expiration_seconds) do
    scheduled_at_utc =
      DateTime.utc_now()
      |> DateTime.add(expiration_seconds, :second)

    new(
      %{
        file_id: file_id,
        file_name: file_name
      },
      scheduled_at: scheduled_at_utc
    )
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "file_name" => file_name,
          "file_id" => file_id
        }
      }) do
    Logger.metadata(oban_job_id: id)

    Logger.info("Deleting expired earnings file: #{file_name}(#{file_id})")

    # B2 integration removed - file deletion disabled
    Logger.info("File deletion disabled - B2 integration removed")
    {:ok, :deletion_disabled}
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(1)
end
