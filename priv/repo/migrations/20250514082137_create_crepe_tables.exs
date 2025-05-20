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

    create table(:crepe_event) do
      add :collected_at, :utc_datetime, null: false
      add :content, :text, null: false
      add :data_field_id, references(:crepe_data_field, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:crepe_event, [:user_id])
    create index(:crepe_event, [:collected_at])
    create index(:crepe_event, [:data_field_id])
  end
end
