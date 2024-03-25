defmodule DriversSeatCoop.CommunityInsights.Oban.ImportCommunityInsightsPayStatsDSC do
  @moduledoc """
  This job will be responsible for updating community insights average hourly pay stats
  """
  use Oban.Worker,
    queue: :analytics,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing],
      keys: [:metro_area_id]
    ],
    max_attempts: 2

  require Logger

  alias DriversSeatCoop.LegacyDSC
  alias DriversSeatCoop.Regions

  @doc """
  Run stats update for all metro areas every day for the current week.
  For other weeks, divide group into
  """
  def schedule_job do
    Regions.get_metro_areas()
    |> Enum.map(fn metro -> metro.id end)
    |> Enum.each(fn metro_area_id -> schedule_job(metro_area_id) end)
  end

  def schedule_job(metro_area_id) do
    new(%{
      metro_area_id: metro_area_id
    })
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "metro_area_id" => metro_area_id
        }
      }) do
    Logger.metadata(oban_job_id: id)

    Logger.info("Import Community Insights Pay Stats for metro #{metro_area_id}")

    LegacyDSC.update_avg_hr_pay_stats_for_metro_area(metro_area_id)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{id: id}) do
    Logger.metadata(oban_job_id: id)

    Logger.info("Import Community Insights Pay Stats")

    schedule_job()
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(60)
end
