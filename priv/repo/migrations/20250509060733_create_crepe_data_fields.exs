defmodule DriversSeatCoop.Repo.Migrations.CreateCrepeDataFields do
  use Ecto.Migration

  def change do
    create table(:crepe_data_fields) do
      add :graph_query, :text, null: false
      add :name, :string, null: false
      add :crepe_collector_id, references(:crepe_collectors, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:crepe_data_fields, [:crepe_collector_id])
  end
end
