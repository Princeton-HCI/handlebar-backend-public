defmodule DriversSeatCoopWeb.UserController do
  use DriversSeatCoopWeb, :controller

  alias DriversSeatCoop.{Accounts, Authorizer, Shifts}
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Legal
  alias DriversSeatCoop.Notifications.Oban.CTAEarningsInsights
  alias DriversSeatCoopWeb.AuthenticationPlug
  alias DriversSeatCoopWeb.UserValidator

  action_fallback DriversSeatCoopWeb.FallbackController

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params) do
      token = Accounts.token_for_user_id(user.id)
      CTAEarningsInsights.schedule_job(user)

      # newly created users cannot have an active shift
      user = user |> Map.put(:currently_on_shift, nil)

      # newly created users cannot have accepted terms
      user = user |> Map.put(:agreed_to_current_terms, false)

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> AuthenticationPlug.put_auth_header(token)
      |> render("show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    with :ok <- Authorizer.authorize(:update, user, conn.assigns.user) do
      Accounts.delete_user(user)

      conn
      |> send_resp(:no_content, "")
    end
  end

  def lookup(conn, %{"email" => email}) do
    Accounts.get_user_by_email(email)
    |> case do
      nil ->
        conn
        |> send_resp(:not_found, "")

      _ ->
        conn
        |> send_resp(:no_content, "")
    end
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    with :ok <- Authorizer.authorize(:show, user, conn.assigns.user) do
      user = put_current_shift(user, Map.get(conn.assigns, :dsc_device))
      user = put_user_agreed_to_current_terms(user)
      render(conn, "show.json", user: user)
    end
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    with :ok <- Authorizer.authorize(:update, user, conn.assigns.user),
         {:ok, user_params} <- UserValidator.update(user_params),
         {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
      CTAEarningsInsights.schedule_job(user)

      user = put_current_shift(user, Map.get(conn.assigns, :dsc_device))
      user = put_user_agreed_to_current_terms(user)
      render(conn, "show.json", user: user)
    end
  end

  defp put_current_shift(user, nil) do
    user |> Map.put(:currently_on_shift, Shifts.get_current_shift_id(user.id, nil))
  end

  defp put_current_shift(user, device) do
    user |> Map.put(:currently_on_shift, Shifts.get_current_shift_id(user.id, device.id))
  end

  defp put_user_agreed_to_current_terms(user) do
    terms_current =
      case Legal.user_has_agreed_to_latest_terms_by(user, NaiveDateTime.utc_now()) do
        :ok ->
          true

        {:error, _} ->
          false
      end

    Map.put(user, :agreed_to_current_terms, terms_current)
  end
end
