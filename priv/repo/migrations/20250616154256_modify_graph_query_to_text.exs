defmodule DriversSeatCoop.Repo.Migrations.ModifyGraphQueryToText do
  use Ecto.Migration

  def change do
    alter table(:crepe_data_field) do
      modify :graph_query, :text
    end
  end
end
