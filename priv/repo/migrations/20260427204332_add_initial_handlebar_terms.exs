defmodule DriversSeatCoop.Repo.Migrations.AddInitialHandlebarTerms do
  use Ecto.Migration

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Legal.Terms
  import Ecto.Query

  def up do
    # We will assume user_id 1 is your admin/system user. Change this if needed!
    system_user_id = 1

    Repo.insert!(%Terms{
      title: "Handlebar Initial Terms of Service",
      text: "These are the initial terms and conditions for Handlebar...",
      required_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      user_id: system_user_id
    })
  end

  def down do
    from(t in Terms, where: t.title == "Handlebar Initial Terms of Service")
    |> Repo.delete_all()
  end
end
