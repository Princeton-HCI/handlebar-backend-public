defmodule DriversSeatCoop.Repo.Migrations.AddCollectionIntervalToCrepeCollector do
  use Ecto.Migration

  def change do
    alter table(:crepe_collector) do
      # Seconds between captures for this collector. NULL (or 0) means
      # "collect every time it matches". Enforcement lives on-device; the
      # backend only stores and serves the value.
      add :collection_interval_seconds, :integer, null: true
    end
  end
end
