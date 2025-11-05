defmodule DriversSeatCoopWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use DriversSeatCoopWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    Sentry.capture_message("INVALID REQUEST", extra: %{changeset: inspect(changeset)})

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(DriversSeatCoopWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, index, %Ecto.Changeset{} = changeset, _state}) do
    Sentry.capture_message("INVALID BULK REQUEST",
      extra: %{index: index, changeset: inspect(changeset)}
    )

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(DriversSeatCoopWeb.ChangesetView)
    |> render("error_multi.json", changeset: changeset, index: index)
  end

  def call(conn, {:error, :conflict}) do
    conn
    |> put_status(:conflict)
    |> put_view(DriversSeatCoopWeb.ErrorView)
    |> render(:"409")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(DriversSeatCoopWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(DriversSeatCoopWeb.ErrorView)
    |> render(:"403")
  end

  def call(conn, {:error, :bad_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(DriversSeatCoopWeb.ErrorView)
    |> render(:"401")
  end
end
