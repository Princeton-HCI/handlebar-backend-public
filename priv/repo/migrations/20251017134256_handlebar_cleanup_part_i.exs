defmodule DriversSeatCoop.Repo.Migrations.HandlebarCleanupPartI do
  use Ecto.Migration

  def change do
  drop_if_exists table(:expenses)
  drop_if_exists table(:user_app_preferences)
  execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_referral_source_id_fkey")
  drop_if_exists table(:referral_sources)
  execute("DROP TYPE IF EXISTS referral_type")
  end
end
