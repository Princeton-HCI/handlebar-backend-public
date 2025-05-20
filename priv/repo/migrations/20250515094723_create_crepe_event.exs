defmodule DriversSeatCoop.Repo.Migrations.CreateCrepeEvent do
  use Ecto.Migration

  def change do
    create table(:crepe_event) do
      add :data_field_id, :string, null: false
      add :collected_at, :utc_datetime, null: false
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:crepe_event, [:user_id])
    create index(:crepe_event, [:collected_at])
    create index(:crepe_event, [:data_field_id])
  end
end
