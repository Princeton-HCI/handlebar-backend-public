defmodule DriversSeatCoop.Repo.Migrations.CreateCrepeTables do
  use Ecto.Migration

  def change do
    create table(:crepe_collector) do
      add :app_name, :string, null: false
      add :app_package, :string, null: false
      add :description, :string

      timestamps()
    end

    create index(:crepe_collector, [:app_package])

    create table(:crepe_data_field) do
      add :name, :string, null: false
      add :graph_query, :string, null: false
      add :collector_id, references(:crepe_collector, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:crepe_data_field, [:collector_id])
    create index(:crepe_data_field, [:name])

    create unique_index(:crepe_data_field, [:collector_id, :name], name: :crepe_data_field_collector_name_index)
  end
end
