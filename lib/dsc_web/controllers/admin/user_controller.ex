defmodule DriversSeatCoopWeb.Admin.UserController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.ExternalServices

  plug(:put_layout, {DriversSeatCoopWeb.LayoutView, "torch.html"})

  def index(conn, params) do
    case Accounts.paginate_users(params) do
      {:ok, assigns} ->
        render(conn, "index.html", assigns)

      error ->
        conn
        |> put_flash(:error, "There was an error rendering Users. #{inspect(error)}")
        |> redirect(to: Routes.admin_user_path(conn, :index))
    end
  end

  def new(conn, _params) do
    changeset = Accounts.change_user(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.admin_user_path(conn, :show, user))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "show.html", user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    case Accounts.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: Routes.admin_user_path(conn, :show, user))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    {:ok, _user} = Accounts.delete_user(user)

    conn
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: Routes.admin_user_path(conn, :index))
  end

  def burninate(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    # delete external services references
    with {:ok, _} <- ExternalServices.delete_user(user) do
      Accounts.purge_user!(id)

      conn
      |> put_flash(:info, "User purged")
      |> redirect(to: Routes.admin_user_path(conn, :index))
    end
  end
end
