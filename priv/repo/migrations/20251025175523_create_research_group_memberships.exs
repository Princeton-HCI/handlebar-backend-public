defmodule DriversSeatCoop.Repo.Migrations.CreateResearchGroupMemberships do
  use Ecto.Migration

  def change do
    create table(:research_group_memberships) do
      add :research_group_id, references(:research_groups, on_delete: :delete_all, type: :bigint), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint), null: false
      add :role, :text, null: false
      add :enrolled_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :unenrolled_at, :utc_datetime

      add :retention_pref_on_unenroll, :text, null: false, default: "keep_collected"

      timestamps(updated_at: false)
    end

    create constraint(:research_group_memberships, :role_must_be_valid,
      check: "role IN ('researcher', 'participant')"
    )

    create constraint(:research_group_memberships, :retention_pref_valid,
      check: "retention_pref_on_unenroll IN ('keep_collected','delete_all')"
    )

    create constraint(:research_group_memberships, :unenroll_after_enroll,
      check: "unenrolled_at IS NULL OR unenrolled_at >= enrolled_at"
    )

    create unique_index(:research_group_memberships, [:research_group_id, :user_id],
      name: :rgm_unique_member
    )
  end
end
