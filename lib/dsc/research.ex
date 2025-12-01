defmodule DriversSeatCoop.Research do
  @moduledoc """
  The Research context.

  This context manages research groups, their memberships, and the collectors
  (data collection apps) attached to those groups.
  """

  import Ecto.Query, warn: false

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Crepe.Collector
  alias DriversSeatCoop.Crepe.CrepeEvent
  alias DriversSeatCoop.Research.ResearchGroup
  alias DriversSeatCoop.Research.ResearchGroupMembership
  alias DriversSeatCoop.Research.ResearchGroupCollector

  # -------------------------
  # RESEARCH GROUPS
  # -------------------------

  @doc """
  Returns the list of research_groups.

  ## Examples

      iex> list_research_groups()
      [%ResearchGroup{}, ...]

  """
  def list_research_groups do
    Repo.all(ResearchGroup)
  end

  @doc """
  Lists all research groups that a user is currently an active member of
  and which role they have.

  Active means `unenrolled_at` is `nil`.
  """
  def list_user_research_groups(user_id) do
    from(rg in ResearchGroup,
      join: m in ResearchGroupMembership,
      on: m.research_group_id == rg.id,
      where: m.user_id == ^user_id and is_nil(m.unenrolled_at),
      select: %{group: rg, role: m.role},
      order_by: [asc: rg.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single research group by ID.

  Returns `nil` if not found.

  ## Examples

      iex> get_research_group!(123)
      %ResearchGroup{}

      iex> get_research_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_research_group(id), do: Repo.get(ResearchGroup, id)

  @doc """
  Gets a single research group by its code, case-insensitive.

  """
  def get_research_group_by_case_insensitive_code(code) do
    from(rg in ResearchGroup,
      where: fragment("lower(?) = lower(?)", rg.code, ^code)
    )
    |> Repo.one()
  end

  @doc """
  Creates a research group.

  A random 10-character code is generated. If the attrs include `"user_id"`,
  that user is automatically enrolled in the group as a `"researcher"`.
  """
  def create_research_group(attrs \\ %{}) do
    with {:ok, rg} <- try_create_with_code(attrs, 10) do
      # Enroll creator as researcher
      if user_id = Map.get(attrs, "user_id") do
        DriversSeatCoop.Research.enroll_user(user_id, rg.id, "researcher")
      end
      {:ok, rg}
    end
  end

  defp try_create_with_code(attrs, attempts_left) when attempts_left > 0 do
    code = random_code()

    %ResearchGroup{}
    |> ResearchGroup.changeset(Map.put(attrs, "code", code))
    |> Repo.insert()
    |> case do
      {:ok, rg} ->
        {:ok, rg}

      {:error, %Ecto.Changeset{errors: [code: {"has already been taken", _}]} = _cs} ->
        try_create_with_code(attrs, attempts_left - 1)

      {:error, cs} ->
        {:error, cs}
    end
  end

  defp random_code() do
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    for _ <- 1..10, into: "", do: <<Enum.at(alphabet, :rand.uniform(length(alphabet)) - 1)>>
  end

  @doc """
  Updates an existing research_group.

  ## Examples

      iex> update_research_group(research_group, %{field: new_value})
      {:ok, %ResearchGroup{}}

      iex> update_research_group(research_group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_research_group(%ResearchGroup{} = research_group, attrs) do
    research_group
    |> ResearchGroup.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a research group.
  This assumes collectors are per-group. In the future, if we make them
  publishable/shared this function will have to change (1 of 2)

  """
  def delete_research_group(%ResearchGroup{} = research_group) do
  Repo.transaction(fn ->
      group_id = research_group.id
      # Gets collectors associated with this group
      rgc_records =
        from(rgc in ResearchGroupCollector,
          where: rgc.research_group_id == ^group_id,
          select: rgc.collector_id
        )
        |> Repo.all()

      # Delete the associated Collector records
      if rgc_records != [] do
        collector_delete_query = from(c in Collector,
          where: c.id in ^rgc_records)

        Repo.delete_all(collector_delete_query)
      end

      # Delete the ResearchGroup record
      case Repo.delete(research_group) do
        {:ok, deleted_group} ->
          deleted_group
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  # -------------------------
  # RESEARCH GROUP MEMBERSHIPS
  # -------------------------

  @doc """
  Lists all members (active and inactive) of a research group.

  This preloads the associated user and orders by user name.

  """
  def list_group_members(group_id) do
    from(m in ResearchGroupMembership,
      join: u in assoc(m, :user),
      where: m.research_group_id == ^group_id,
      preload: [user: u],
      order_by: [asc: u.last_name, asc: u.first_name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a membership by its ID.

  Returns `nil` if it does not exist.
  """
  def get_membership_by_id(id), do: Repo.get(ResearchGroupMembership, id)

  @doc """
  Gets the active membership for a given user in a given research group.

  Returns `nil` if the user is not currently enrolled (i.e. no record or has `unenrolled_at`).
  """
  def get_user_membership_for_group(user_id, group_id) do
    from(m in ResearchGroupMembership,
      where: m.user_id == ^user_id and m.research_group_id == ^group_id and is_nil(m.unenrolled_at),
      limit: 1
    )
    |> Repo.one()
  end

  def only_active_researcher?(group_id) do
    active_researchers_count =
      from(m in ResearchGroupMembership,
        where:
          m.research_group_id == ^group_id and
          m.role == "researcher" and
          is_nil(m.unenrolled_at)
      )
      |> Repo.aggregate(:count, :id)

    active_researchers_count == 1
  end

  @doc """
  Updates a user's research group membership.

  The updated membership is returned with the `:user` association preloaded.
  """
  def update_membership(%ResearchGroupMembership{} = membership, attrs) do
    membership
    |> ResearchGroupMembership.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, m} -> {:ok, Repo.preload(m, :user)}
      error -> error
    end
  end

  @doc """
  Enrolls a user into a research group with the given role.

  If a membership already exists (conflict on `[:research_group_id, :user_id]`),
  it will be reactivated (`unenrolled_at` set to `nil`) and its role updated.
  """
  def enroll_user(user_id, research_group_id, role \\ "participant") do
    Ecto.Multi.new()
    |> enroll_user_multi(user_id, research_group_id, role)
    |> Repo.transaction()
    |> case do
      {:ok, %{enroll: membership}} ->
        {:ok, Repo.preload(membership, :user)}

      {:error, _op, reason, _changes} ->
        {:error, reason}
    end
  end

  defp enroll_user_multi(multi, user_id, research_group_id, role) do
    membership = %ResearchGroupMembership{user_id: user_id, research_group_id: research_group_id}
    attrs = %{role: role, enrolled_at: DateTime.utc_now()}

    changeset = ResearchGroupMembership.changeset(membership, attrs)
    Ecto.Multi.insert(multi, :enroll, changeset,
      on_conflict: [
        set: [unenrolled_at: nil, enrolled_at: DateTime.utc_now(), role: role]
      ],
      conflict_target: [:research_group_id, :user_id],
      returning: true
    )
  end

  @type unenroll_policy :: :keep_collected | :delete_all

  @doc """
  Unenrolls a user from a research group.

  Marks the membership's `unenrolled_at` timestamp and
  applies the retention policy to collected events for that user in that group.

  """
  def unenroll_user(user_id, group_id, policy \\ :keep_collected) do
    Ecto.Multi.new()
    |> unenroll_user_multi(user_id, group_id, policy)
    |> Repo.transaction()
  end

  defp unenroll_user_multi(multi, user_id, group_id, policy) do
    qry =
      from(m in ResearchGroupMembership,
        where: m.user_id == ^user_id and m.research_group_id == ^group_id and is_nil(m.unenrolled_at)
      )

    multi
    |> Ecto.Multi.update_all(:unenroll, qry, set: [unenrolled_at: DateTime.utc_now()])
    |> Ecto.Multi.run(:apply_retention, fn repo, %{unenroll: {count, _}} ->
      if count == 0 do
        {:ok, :noop}
      else
        case policy do
          :keep_collected -> {:ok, :kept}
          :delete_all -> delete_all_collected_events(repo, user_id, group_id)
        end
      end
    end)
  end

  defp delete_all_collected_events(repo, user_id, group_id) do
    qry =
      from ev in CrepeEvent,
        join: m in ResearchGroupMembership, on: m.id == ev.membership_id,
        where: m.user_id == ^user_id and m.research_group_id == ^group_id

    {events_deleted, _} = repo.delete_all(qry)

    {:ok, {:deleted, %{crepe_events: events_deleted}}}
  end

  # -------------------------
  # RESEARCH GROUP COLLECTORS
  # -------------------------

  @doc """
  Lists all collectors attached to a research group.

  Each collector is returned with its `data_fields` preloaded.
  """
  def list_group_collectors(group_id) do
    from(c in Collector,
      join: rgc in ResearchGroupCollector, on: rgc.collector_id == c.id,
      left_join: df in assoc(c, :data_fields),
      where: rgc.research_group_id == ^group_id,
      order_by: [asc: c.app_name],
      preload: [data_fields: df],
      distinct: true
    )
    |> Repo.all()
  end

  @doc """
  Gets a research-group–collector join entry for a given group and collector.

  Returns `nil` if the collector is not attached to that group.
  """
  def get_research_group_collector(group_id, collector_id) do
    from(rgc in ResearchGroupCollector,
      where: rgc.research_group_id == ^group_id and rgc.collector_id == ^collector_id,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Lists all distinct collectors, corresponding membership IDs,
  and corresponding group names where the user is an active participant.
  """
  def list_participant_collectors(user_id) do
    from(c in DriversSeatCoop.Crepe.Collector,
      join: rgc in DriversSeatCoop.Research.ResearchGroupCollector,
        on: rgc.collector_id == c.id,
      join: m in DriversSeatCoop.Research.ResearchGroupMembership,
        on: m.research_group_id == rgc.research_group_id,
      join: rg in DriversSeatCoop.Research.ResearchGroup,
        on: rg.id == m.research_group_id,
      where:
        m.user_id == ^user_id and
        is_nil(m.unenrolled_at) and
        m.role == "participant",
      left_join: df in assoc(c, :data_fields),
      preload: [data_fields: df],
      select: {c, m.id, rg.name},
      distinct: true,
      order_by: [asc: c.app_name]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new collector with at least one data field and attaches
  it to the given research group.
  """
  def create_collector_and_attach(group_id, %{} = collector_attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:collector, Collector.changeset(%Collector{}, collector_attrs))
    |> Ecto.Multi.run(:rgc, fn repo, %{collector: collector} ->
      repo.insert(
        ResearchGroupCollector.changeset(%ResearchGroupCollector{}, %{
          research_group_id: group_id,
          collector_id: collector.id,
          added_at: DateTime.utc_now()
        }),
        on_conflict: :nothing
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{collector: collector}} ->
        {:ok, Repo.preload(collector, :data_fields)}

      {:error, step, changeset, changes_so_far} ->
        {:error, step, changeset, changes_so_far}
    end
  end

  @doc """
  Deletes a research group collector and the underlying collector record.

  This assumes the collector is not shared across multiple groups. If
  collectors become shared, this function will need to change (2 of 2)
  """
  def delete_research_group_collector(%DriversSeatCoop.Research.ResearchGroupCollector{} = rgc) do
    collector = Repo.get!(DriversSeatCoop.Crepe.Collector, rgc.collector_id)
    Repo.delete(collector)
    # Cascade also deletes the rgc
  end

  # -------------------------
  # CREPE EVENTS
  # -------------------------
  def list_crepe_events(filters \\ [], pagination_opts \\ %{}) do
    # Base query
    base_query = from(e in CrepeEvent)
      |> maybe_join_membership(filters)
      |> apply_crepe_event_filters(filters)
      |> with_crepe_event_preloads()
      |> order_by([e], [desc: e.collected_at, desc: e.id])

    # cursor fields for pagination, newest first
    cursor_fields = [{:collected_at, :desc}, {:id, :desc}]

    # defaults
    default_opts = %{
      cursor_fields: cursor_fields,
      limit: 50
    }

    opts_map = Map.merge(default_opts, pagination_opts)

    opts_keyword = Keyword.new(opts_map)

    Repo.paginate(base_query, opts_keyword)
  end

  defp maybe_join_membership(query, filters) do
    # Check if filters require a membership role
    needs_join =
      Keyword.has_key?(filters, :group_id) or
      Keyword.has_key?(filters, :role) or
      Keyword.has_key?(filters, :active_membership)

    if needs_join do
      join(query, :left, [e], m in assoc(e, :membership), [as :m])
    else
      query
    end
  end

  defp apply_crepe_event_filters(query, filters) do
    # add filter by user if applicable
    query =
      if user_id = filters[:user_id] do
        where(query, [e], e.user_id == ^user_id)
      else
        query
      end

    # add filter by membership if applicable
    query =
      if membership_id = filters[:membership_id] do
        where(query, [e], e.membership_id == ^membership_id)
      else
        query
      end

    # add filter by groupid if applicable
    query =
      if group_id = filters[:group_id] do
        where(query, [e, m], m.research_group_id == ^group_id)
      else
        query
      end

    # add filter by role if applicable
    query =
      if role = filters[:role] do
        where(query, [e, m], m.role == ^role)
      else
        query
      end

    # add filter by active membership if applicable
    query =
      if filters[:active_membership] == true do
        where(query, [e, m], is_nil(m.unenrolled_at))
      else
        query
      end

    query
  end

  defp with_crepe_event_preloads(query) do
    # Preload the user, data fields membership, and research group
    query
      |> preload([:user, :data_field, membership: :research_group])
  end

  def create_crepe_event(attrs, user_id) do
    # TODO: Define notification behavior here based on user and/or data field
    notification = nil

    with {:ok, crepe_event} <-
           %CrepeEvent{user_id: user_id}
           |> CrepeEvent.changeset(attrs)
           |> Repo.insert() do
      {:ok, %{crepe_event: crepe_event, notification: notification}}
    end
  end

  def query_membership, do: from(m in ResearchGroupMembership)

  def query_membership_filter_active(qry), do: where(qry, [m], is_nil(m.unenrolled_at))

  def query_membership_filter_groups(qry, group_id_or_ids) do
    group_id_or_ids = List.wrap(group_id_or_ids)
    where(qry, [m], m.research_group_id in ^group_id_or_ids)
  end

  def query_membership_filter_users(qry, user_id_or_ids) do
    user_id_or_ids = List.wrap(user_id_or_ids)
    where(qry, [m], m.user_id in ^user_id_or_ids)
  end
end
