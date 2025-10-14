defmodule DriversSeatCoop.Authorizer do
  @moduledoc """
  Authorizes whether a certain action can be done on a given resource by a user

  There is only one function signature, in the form of:
  `def authorize(action, resource, user)`

  Currently all resources have a user_id that must be equal to the user trying to take that action.
  """

  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Legal.AcceptedTerms
  alias DriversSeatCoop.Shifts.Shift

  @spec authorize(atom(), struct(), struct()) :: :ok | {:error, :unauthorized}
  def authorize(:show, %User{id: user_id}, %User{} = current_user) do
    if current_user.id == user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def authorize(:update, %User{id: user_id}, %User{} = current_user) do
    if current_user.id == user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def authorize(:show, %AcceptedTerms{user_id: user_id}, %User{} = current_user) do
    if current_user.id == user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def authorize(:show, %Shift{user_id: user_id}, %User{} = current_user) do
    if current_user.id == user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def authorize(:update, %Shift{user_id: user_id}, %User{} = current_user) do
    if current_user.id == user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end
end
