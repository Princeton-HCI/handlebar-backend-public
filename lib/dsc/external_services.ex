defmodule DriversSeatCoop.ExternalServices do
  import Ecto.Query, warn: false

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Accounts.UserServiceIdentifier
  alias DriversSeatCoop.Mixpanel
  alias DriversSeatCoop.Repo

  @services [
    :mixpanel
  ]

  def query, do: from(x in UserServiceIdentifier)

  def query_filter_user(qry, user_id_or_ids, include_or_exclude \\ true) do
    user_id_or_ids = List.wrap(user_id_or_ids)

    if include_or_exclude,
      do: where(qry, [x], x.user_id in ^user_id_or_ids),
      else: where(qry, [x], x.user_id not in ^user_id_or_ids)
  end

  def query_filter_service(qry, service_or_services, include_or_exclude \\ true) do
    service_or_services =
      List.wrap(service_or_services)
      |> Enum.map(fn svc -> "#{svc}" end)

    if include_or_exclude,
      do: where(qry, [x], x.service in ^service_or_services),
      else: where(qry, [x], x.service not in ^service_or_services)
  end

  def get_identifiers_for_user(user_id, service) do
    query()
    |> query_filter_user(user_id)
    |> query_filter_service(service)
    |> Repo.one()
  end

  def set_identifiers(user_id, service, identifiers) do
    identifiers = List.wrap(identifiers)
    service = "#{service}"

    if Enum.any?(identifiers) do
      attrs = %{
        user_id: user_id,
        service: service,
        identifiers: identifiers
      }

      existing =
        get_identifiers_for_user(user_id, service) ||
          %UserServiceIdentifier{
            user_id: user_id
          }

      changeset = UserServiceIdentifier.changeset(existing, attrs)

      Repo.insert_or_update(changeset,
        on_conflict: {:replace, [:identifiers, :updated_at]},
        conflict_target: [:user_id, :service]
      )
    else
      clear_identifiers(user_id, service)
    end
  end

  def clear_identifiers(user_id, service) do
    service = "#{service}"

    from(p in UserServiceIdentifier,
      where: p.user_id == ^user_id,
      where: p.service == ^service
    )
    |> Repo.delete_all(timeout: :infinity)
  end

  def calculate_identifier_changes(service, user_or_users \\ nil) do
    service = "#{service}"

    qry =
      query()
      |> join(:right, [x], u in User, on: x.user_id == u.id and x.service == ^service)
      |> select([x, u], %{
        user_id: u.id,
        email: fragment("LOWER(?)", u.email),
        dsc_identifiers: fragment("COALESCE(?, ARRAY[]::text[])", x.identifiers)
      })

    qry =
      if is_nil(user_or_users) do
        qry
      else
        user_or_users = List.wrap(user_or_users)
        where(qry, [x, u], u.id in ^user_or_users)
      end

    dsc_identifiers = Repo.all(qry)
    svc_identifiers = get_external_identifiers(service)

    (svc_identifiers ++ dsc_identifiers)
    |> Enum.reduce(%{}, fn x, model ->
      result =
        Map.get(model, x.email, %{})
        |> Map.merge(x)

      Map.put(model, x.email, result)
    end)
    |> Map.values()
    |> Enum.filter(fn x ->
      Map.has_key?(x, :user_id) and Map.get(x, :dsc_identifiers) != Map.get(x, :svc_identifiers)
    end)
  end

  def update_external_identifiers(service) do
    changes = calculate_identifier_changes(service)

    Enum.filter(changes, fn chg -> Map.has_key?(chg, :user_id) end)
    |> Enum.each(fn chg ->
      cond do
        # no service identifiers, existing dsc identifiers
        Map.get(chg, :svc_identifiers, []) == [] and Map.get(chg, :dsc_identifiers, []) != [] ->
          clear_identifiers(chg.user_id, service)

        Map.get(chg, :svc_identifiers, []) != [] ->
          set_identifiers(chg.user_id, service, chg.svc_identifiers)

        true ->
          :no_op
      end
    end)
  end

  def get_external_identifiers("mixpanel") do
    {:ok, :results, mx_users} =
      Mixpanel.query_users()
      |> Mixpanel.query_users_with_output_field(:email)
      |> Mixpanel.query_users_exec()

    mx_users
    |> Enum.filter(fn mxu -> not is_nil(Map.get(mxu, "email")) end)
    |> Enum.group_by(
      fn mxu -> String.downcase(Map.get(mxu, "email")) end,
      fn mxu -> Map.get(mxu, "$distinct_id") end
    )
    |> Enum.map(fn {email, identifiers} ->
      %{
        email: email,
        svc_identifiers: Enum.sort(identifiers)
      }
    end)
  end

  def delete_user(%User{} = user) do
    # iterate through each service and collect any errors in a map
    # keyed by service
    problems =
      Enum.reduce(@services, %{}, fn svc, problems ->
        case delete_user(user, svc) do
          {:ok, _} -> problems
          {:error, issues} -> Map.put(problems, svc, issues)
          x -> Map.put(problems, svc, x)
        end
      end)

    if problems == %{}, do: {:ok, :deleted}, else: {:error, problems}
  end

  def delete_user(user_id) do
    user = Accounts.get_user!(user_id)
    delete_user(user)
  end

  def delete_user(%User{} = user, service) do
    service = "#{service}"

    xref =
      query()
      |> query_filter_user(user.id)
      |> query_filter_service(service)
      |> Repo.one()

    if is_nil(xref) or List.wrap(xref.identifiers) == [] do
      {:ok, :nothing_to_delete}
    else
      problems = delete_user_impl(user, service, xref.identifiers)

      if Enum.any?(problems) do
        {:error, problems}
      else
        DriversSeatCoop.Repo.delete!(xref)
        {:ok, :deleted}
      end
    end
  end

  def delete_user(user_id, service) do
    user = Accounts.get_user!(user_id)
    delete_user(user, service)
  end

  defp delete_user_impl(%User{} = user, "mixpanel" = _service, distinct_id_or_ids) do
    distinct_id_or_ids = List.wrap(distinct_id_or_ids)
    is_prod_user = User.is_prod_user(user)

    Enum.reduce(distinct_id_or_ids, [], fn distinct_id, problems ->
      del_result =
        if is_prod_user,
          do: Mixpanel.deidentify_user(distinct_id),
          else: Mixpanel.delete_user(distinct_id)

      case del_result do
        # delete was successful
        {:ok, _} ->
          problems

        # anything else is a problem
        true ->
          List.insert_at(problems, -1, {distinct_id, del_result})
      end
    end)
  end
end
