defmodule DriversSeatCoop.Repo.Migrations.CreateCrepeCollectorTable do
  use Ecto.Migration

  def change do
    create table(:crepe_collector) do
      add :app_name, :string, null: false
      add :app_package, :string, null: false
      add :description, :string

      timestamps()
    end

    create index(:crepe_collector, [:app_package])
  end
end
