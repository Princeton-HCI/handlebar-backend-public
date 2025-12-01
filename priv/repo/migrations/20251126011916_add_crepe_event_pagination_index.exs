defmodule DriversSeatCoop.Repo.Migrations.AddCrepeEventPaginationIndex do
  use Ecto.Migration

  def change do
    create index(:crepe_event, [:collected_at, :id])
  end
end
