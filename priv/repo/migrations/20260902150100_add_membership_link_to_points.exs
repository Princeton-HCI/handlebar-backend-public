defmodule DriversSeatCoop.Repo.Migrations.AddMembershipLinkToPoints do
  use Ecto.Migration

  def change do
    alter table(:points) do
      # Which study membership this point was collected for. Nullable, unlike
      # crepe_event.membership_id, because the legacy Driver's Seat path writes
      # points with no study context at all.
      add :membership_id, references(:research_group_memberships, on_delete: :restrict),
        null: true
    end

    # Supports retention deletion on unenrollment and per-study point queries.
    create index(:points, [:membership_id, :recorded_at])
  end
end
