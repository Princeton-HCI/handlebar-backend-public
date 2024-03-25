defmodule DriversSeatCoop.CommunityInsights.AverageHourlyPayStatDSC do
  use Ecto.Schema
  import Ecto.Changeset
  alias DriversSeatCoop.Employers.EmployerServiceClass
  alias DriversSeatCoop.Regions.MetroArea

  @zero Decimal.new(0)
  @required_fields ~w(
      week_start_date
      day_of_week
      hour_local
      employer_service_class_id
      metro_area_id
      count_activities
      count_tasks
      count_users
      count_week_samples
      week_sample_first
      week_sample_last
      duration_seconds
      earnings_total_cents
      earnings_avg_hr_cents
      earnings_avg_hr_cents_with_mileage
    )a

  @optional_fields ~w(
      distance_miles
      deduction_mileage_cents
    )a

  schema "community_insights_avg_hr_pay_stats_dsc" do
    belongs_to(:metro_area, MetroArea)
    field :week_start_date, :date
    belongs_to(:employer_service_class, EmployerServiceClass)
    field :day_of_week, :integer
    field :hour_local, :time

    field :count_activities, :integer
    field :count_tasks, :integer
    field :count_users, :integer
    field :count_week_samples, :integer
    field :week_sample_first, :date
    field :week_sample_last, :date

    field :duration_seconds, :integer
    field :earnings_total_cents, :integer
    field :distance_miles, :decimal
    field :deduction_mileage_cents, :integer

    field :earnings_avg_hr_cents, :integer
    field :earnings_avg_hr_cents_with_mileage, :integer

    timestamps()
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:count_activities, greater_than_or_equal_to: 0)
    |> validate_number(:count_tasks, greater_than_or_equal_to: 0)
    |> validate_number(:count_users, greater_than_or_equal_to: 0)
    |> validate_number(:count_week_samples, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:deduction_mileage_cents, greater_than_or_equal_to: 0)
    |> validate_number(:distance_miles, greater_than_or_equal_to: @zero)
    |> validate_time_truncated_to_hour(:hour_local)
    |> validate_number(:day_of_week, greater_than_or_equal_to: 0, less_than_or_equal_to: 6)
    |> assoc_constraint(:employer_service_class)
    |> assoc_constraint(:metro_area)
    |> unique_constraint(
      [:metro_area_id, :week_start_date, :employer_service_class_id, :day_of_week, :hour_local],
      name: "community_insights_avg_hr_pay_stats_dsc_ak"
    )
  end

  def validate_time_truncated_to_hour(changeset, field) when is_atom(field) do
    validate_change(changeset, field, fn field, value ->
      case value do
        %Time{minute: 0, second: 0, microsecond: {0, 0}} -> []
        _ -> [{field, "values must be precise to the hour"}]
      end
    end)
  end
end
