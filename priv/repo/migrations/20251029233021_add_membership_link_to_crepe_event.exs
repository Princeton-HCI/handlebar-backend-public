defmodule DriversSeatCoop.Repo.Migrations.AddMembershipLinkToCrepeEvent do
  use Ecto.Migration

  def change do
    alter table(:crepe_event) do
      add :membership_id, references(:research_group_memberships, on_delete: :restrict), null: false
    end

    create index(:crepe_event, [:membership_id, :collected_at])
    create index(:crepe_event, [:user_id, :collected_at]) 
  end
end
