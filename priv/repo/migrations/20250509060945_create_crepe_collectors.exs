defmodule DriversSeatCoop.Repo.Migrations.CreateCrepeCollectors do
  use Ecto.Migration

  def change do
    create table(:crepe_collectors) do
      add :app_name, :string, null: false
      add :app_package, :string, null: false
      add :description, :text

      timestamps()
    end

    create index(:crepe_collectors, [:app_package])
  end
end
