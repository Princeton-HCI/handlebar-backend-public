defmodule DriversSeatCoop.Repo.Migrations.IncorporateDscInsightsDataIntoCalc do
  use Ecto.Migration

  def change do
    create table(:community_insights_avg_hr_pay_stats_dsc) do
      add(:week_start_date, :date, null: false)
      add(:day_of_week, :integer, null: false)
      add(:hour_local, :time, null: false)

      add(:employer_service_class_id, references(:employer_service_classes, on_delete: :nothing),
        null: false
      )

      add(:metro_area_id, references(:region_metro_area, on_delete: :nothing), null: false)

      add(:count_activities, :integer, null: false)
      add(:count_tasks, :integer, null: false)
      add(:count_users, :integer, null: false)
      add(:count_week_samples, :integer, null: false)
      add(:week_sample_first, :date, null: false)
      add(:week_sample_last, :date, null: false)

      add(:duration_seconds, :integer, null: false)
      add(:earnings_total_cents, :integer, null: false)
      add(:distance_miles, :decimal, null: true)
      add(:deduction_mileage_cents, :integer, null: true)

      add(:earnings_avg_hr_cents, :integer, null: false)
      add(:earnings_avg_hr_cents_with_mileage, :integer, null: false)

      timestamps()
    end

    create unique_index(
             :community_insights_avg_hr_pay_stats_dsc,
             [
               :metro_area_id,
               :week_start_date,
               :employer_service_class_id,
               :day_of_week,
               :hour_local
             ],
             name: :community_insights_avg_hr_pay_stats_dsc_ak
           )
  end
end
