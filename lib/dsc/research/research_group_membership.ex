defmodule DriversSeatCoop.Research.ResearchGroupMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields ~w(research_group_id user_id role enrolled_at retention_pref_on_unenroll)a
  @optional_fields ~w(unenrolled_at)a

  schema "research_group_memberships" do
    belongs_to :user, DriversSeatCoop.Accounts.User
    belongs_to :research_group, DriversSeatCoop.Research.ResearchGroup

    field :role, :string 
    field :enrolled_at, :utc_datetime
    field :unenrolled_at, :utc_datetime
    field :retention_pref_on_unenroll, :string, default: "keep_collected"

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:role, ["researcher", "participant"])
    |> validate_inclusion(:retention_pref_on_unenroll, ["keep_collected", "delete_all"])
    |> assoc_constraint(:user)
    |> assoc_constraint(:research_group)
    |> unique_constraint([:research_group_id, :user_id], name: :rgm_unique_member)
  end
end
