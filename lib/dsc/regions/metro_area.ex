defmodule DriversSeatCoop.Regions.MetroArea do
  use Ecto.Schema
  import Ecto.Changeset

  @sync_fields ~w(id name full_name geometry)a
  @stats_fields ~w(
    count_workers
    hourly_pay_stat_coverage_percent
    hourly_pay_stat_coverage_percent_rideshare
    hourly_pay_stat_coverage_percent_delivery
    hourly_pay_stat_coverage_percent_services
    hourly_pay_stat_coverage_count_workers
    hourly_pay_stat_coverage_count_workers_rideshare
    hourly_pay_stat_coverage_count_workers_delivery
    hourly_pay_stat_coverage_count_workers_services
    hourly_pay_stat_coverage_count_employers
    hourly_pay_stat_coverage_count_employers_rideshare
    hourly_pay_stat_coverage_count_employers_delivery
    hourly_pay_stat_coverage_count_employers_services
    hourly_pay_stat_coverage_count_jobs
    hourly_pay_stat_coverage_count_jobs_rideshare
    hourly_pay_stat_coverage_count_jobs_delivery
    hourly_pay_stat_coverage_count_jobs_services
    hourly_pay_stat_coverage_count_tasks
    hourly_pay_stat_coverage_count_tasks_rideshare
    hourly_pay_stat_coverage_count_tasks_delivery
    hourly_pay_stat_coverage_count_tasks_services
  )a

  @all_fields_except_geometry (@sync_fields ++ @stats_fields) -- [:geometry]

  def get_non_geometry_fields, do: @all_fields_except_geometry

  schema "region_metro_area" do
    field :name, :string
    field :full_name, :string
    field :geometry, Geo.PostGIS.Geometry
    field :count_workers, :integer
    field :hourly_pay_stat_coverage_percent, :decimal
    field :hourly_pay_stat_coverage_percent_rideshare, :decimal
    field :hourly_pay_stat_coverage_percent_delivery, :decimal
    field :hourly_pay_stat_coverage_percent_services, :decimal
    field :hourly_pay_stat_coverage_count_workers, :integer
    field :hourly_pay_stat_coverage_count_workers_rideshare, :integer
    field :hourly_pay_stat_coverage_count_workers_delivery, :integer
    field :hourly_pay_stat_coverage_count_workers_services, :integer
    field :hourly_pay_stat_coverage_count_employers, :integer
    field :hourly_pay_stat_coverage_count_employers_rideshare, :integer
    field :hourly_pay_stat_coverage_count_employers_delivery, :integer
    field :hourly_pay_stat_coverage_count_employers_services, :integer
    field :hourly_pay_stat_coverage_count_jobs, :integer
    field :hourly_pay_stat_coverage_count_jobs_rideshare, :integer
    field :hourly_pay_stat_coverage_count_jobs_delivery, :integer
    field :hourly_pay_stat_coverage_count_jobs_services, :integer
    field :hourly_pay_stat_coverage_count_tasks, :integer
    field :hourly_pay_stat_coverage_count_tasks_rideshare, :integer
    field :hourly_pay_stat_coverage_count_tasks_delivery, :integer
    field :hourly_pay_stat_coverage_count_tasks_services, :integer
  end

  def sync_changeset(metro_area, attrs) do
    metro_area
    |> cast(attrs, @sync_fields)
    |> validate_required(@sync_fields)
    |> unique_constraint([:name])
    |> unique_constraint([:full_name])
  end

  def stats_changeset(metro_area, attrs) do
    metro_area
    |> cast(attrs, @stats_fields)
  end
end
