defmodule DriversSeatCoop.Repo.Migrations.CreateResearchGroupCollectors do
  use Ecto.Migration

  def change do
    create table(:research_group_collectors) do
      add :research_group_id, references(:research_groups, on_delete: :delete_all, type: :bigint), null: false
      add :collector_id, references(:crepe_collector, on_delete: :delete_all, type: :bigint), null: false
      add :added_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end

    create unique_index(:research_group_collectors, [:research_group_id, :collector_id],
      name: :rgc_unique_ids
    )
  end
end
