defmodule DriversSeatCoop.Research do
  @moduledoc """
  The Research context.

  This context manages research groups, their memberships, and the collectors
  (data collection apps) attached to those groups.
  """

  import Ecto.Query, warn: false

  require Logger

  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Crepe.Collector
  alias DriversSeatCoop.Crepe.CrepeEvent
  alias DriversSeatCoop.Research.ResearchGroup
  alias DriversSeatCoop.Research.ResearchGroupMembership
  alias DriversSeatCoop.Research.ResearchGroupCollector
  alias DriversSeatCoop.Research.SensorConfig
  alias DriversSeatCoop.Driving.Point

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
  Lists only the active researchers of a research group.
  """
  def list_group_researchers(group_id) do
    from(m in ResearchGroupMembership,
      join: u in assoc(m, :user),
      # Filter by role and ensure they are still active
      where: m.research_group_id == ^group_id and m.role == "researcher" and m.is_active == true,
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

  @doc """
  Verifies that `membership_id` refers to an active membership owned by `user_id`.

  Used to authorize body-supplied membership ids (e.g. `POST /research/crepe-event`)
  where no URL param drives `EnsureGroupMemberPlug`. Returns `{:ok, membership}` when
  the caller owns the active membership, otherwise `{:error, :not_found}`.
  """
  def get_active_membership_for_user(user_id, membership_id) do
    from(m in ResearchGroupMembership,
      where: m.id == ^membership_id and m.user_id == ^user_id and is_nil(m.unenrolled_at),
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      membership -> {:ok, membership}
    end
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
    events_qry =
      from ev in CrepeEvent,
        join: m in ResearchGroupMembership, on: m.id == ev.membership_id,
        where: m.user_id == ^user_id and m.research_group_id == ^group_id

    {events_deleted, _} = repo.delete_all(events_qry)

    # Location points collected for a study carry the same membership link that
    # crepe events do, so the retention policy has to reach them too. Points with
    # a nil membership_id are legacy Driver's Seat data and are left alone.
    points_qry =
      from p in Point,
        join: m in ResearchGroupMembership, on: m.id == p.membership_id,
        where: m.user_id == ^user_id and m.research_group_id == ^group_id

    {points_deleted, _} = repo.delete_all(points_qry)

    {:ok, {:deleted, %{crepe_events: events_deleted, points: points_deleted}}}
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
  Gets a single collector attached to a research group, with its
  `data_fields` preloaded.

  Returns `nil` if the collector is not attached to that group.
  """
  def get_group_collector(group_id, collector_id) do
    from(c in Collector,
      join: rgc in ResearchGroupCollector, on: rgc.collector_id == c.id,
      where: rgc.research_group_id == ^group_id and c.id == ^collector_id,
      preload: [:data_fields],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Applies a partial update to a collector.

  Only the keys present in `attrs` are changed; data fields are untouched.
  """
  def update_collector(%Collector{} = collector, %{} = attrs) do
    collector
    |> Collector.update_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, collector} -> {:ok, Repo.preload(collector, :data_fields, force: true)}
      {:error, changeset} -> {:error, changeset}
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

  # Primary method to SELECT and DESCRIBE queries with an OpenAI LLM call
  # If successful, should return:
  # {:ok,
  #  %{
  #    101 => %{
  #      best_index: 1,
  #      descriptions: %{
  #        "0" => "element with text Price",
  #        "1" => "clickable element that has a child with text Price"
  #      }
  #    },
  #    102 => %{
  #      best_index: 0,
  #      descriptions: %{
  #        "0" => "input field with hint text Email"
  #      }
  #    }
  #  }}
  def select_and_describe_queries_with_llm(group_id, user_description, entities) do
    with :ok <- validate_llm_query_selection_input(group_id, user_description, entities),
        prompt <- build_llm_query_selection_prompt(user_description, entities),
        _ <- Logger.info("LLM query selection: built prompt for group #{group_id}"),
        {:ok, raw_content} <- call_openai_for_query_selection(prompt),
        _ <- Logger.debug("LLM query selection raw content: #{inspect(raw_content)}"),
        {:ok, parsed_results} <- parse_llm_query_selection_response(raw_content) do
      {:ok, parsed_results}
    else
      {:error, reason} = err ->
        Logger.error("LLM query selection failed: #{inspect(reason)}")
        err

    end
  end

  # Input validation for LLM call
  defp validate_llm_query_selection_input(group_id, user_description, entities) do
    cond do
      not is_integer(group_id) or group_id <= 0 ->
        {:error, :invalid_group_id}

      not is_binary(user_description) or String.trim(user_description) == "" ->
        {:error, :invalid_user_description}

      not is_list(entities) or entities == [] ->
        {:error, :invalid_entities}

      true ->
        :ok
    end
  end

  ######################
  # ----- PROMPT ------
  ######################

  # Constructs the prompt to be fed to the LLM for eval + selection
  defp build_llm_query_selection_prompt(user_description, entities) do
    # Construct queries for each entity
    entity_blocks =
      entities
      |> Enum.map(&build_entity_prompt_block/1)
      |> Enum.join("\n\n")

    """
    You are given graph queries used to locate UI elements.

    TASKS:
    1. For EACH entity, translate EACH query into a short natural language description.
    2. For EACH entity, select which query BEST matches the user's description.

    User description:
    #{user_description}

    Entities and queries:
    #{entity_blocks}

    Examples:
    Query: HAS_TEXT("Submit")
    Description: element with text "Submit"

    Query: HAS_CHILD_TEXT("Price") AND IS_CLICKABLE
    Description: clickable element that has a child with text "Price"

    OUTPUT FORMAT (STRICT JSON ONLY):
    {
      "results": {
        "123": {
          "best_index": 0,
          "descriptions": {
            "0": "...",
            "1": "..."
          }
        },
        "456": {
          "best_index": 1,
          "descriptions": {
            "0": "...",
            "1": "..."
          }
        }
      }
    }

    Rules:
    - Return JSON only
    - No markdown
    - No explanation outside JSON
    - "results" must include every entity_id provided
    - "best_index" must be a valid integer index for that entity
    - "descriptions" must include all indices for that entity
    """
  end

  defp build_entity_prompt_block(%{"entity_id" => entity_id, "queries" => queries}) do
    query_lines =
      queries
      |> Enum.map(fn %{"index" => index, "query" => query} ->
        "#{index}: #{query}"
      end)
      |> Enum.join("\n")

    """
    Entity ID: #{entity_id}
    Queries:
    #{query_lines}
    """
  end

  defp build_entity_prompt_block(%{entity_id: entity_id, queries: queries}) do
    query_lines =
      queries
      |> Enum.map(fn %{index: index, query: query} ->
        "#{index}: #{query}"
      end)
      |> Enum.join("\n")

    """
    Entity ID: #{entity_id}
    Queries:
    #{query_lines}
    """
  end

  ##########################
  # ----- OPENAI CALL ------
  ##########################


  # Do HTTP request to OpenAI and extract the response
  defp call_openai_for_query_selection(prompt) do
    api_key = openai_api_key()
    base_url = openai_base_url()

    body = %{
      model: "gpt-4.1-mini",
      input: prompt
    }

    case Req.post("#{base_url}/responses",
          json: body,
          headers: [
            {"authorization", "Bearer #{api_key}"},
            {"content-type", "application/json"}
          ],
          receive_timeout: 60_000
        ) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case extract_response_text(response_body) do
          {:ok, text} -> {:ok, text}
          {:error, reason} -> {:error, reason}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:openai_http_error, status, body}}

      {:error, reason} ->
        {:error, {:openai_request_failed, reason}}
    end
  end

  defp extract_response_text(%{"output" => output}) when is_list(output) do
    text =
      output
      |> Enum.flat_map(fn item ->
        Map.get(item, "content", [])
      end)
      |> Enum.filter(fn content_item ->
        Map.get(content_item, "type") == "output_text"
      end)
      |> Enum.map_join("", fn content_item ->
        Map.get(content_item, "text", "")
      end)

    if String.trim(text) == "" do
      {:error, :empty_openai_response_text}
    else
      {:ok, text}
    end
  end

  defp extract_response_text(_), do: {:error, :unexpected_openai_response_shape}

  # Parse and normalize the structured JSON into what the frontend expects
  defp parse_llm_query_selection_response(raw_content) when is_binary(raw_content) do
    cleaned =
      raw_content
      |> String.trim()
      |> strip_wrapping_code_fence()

    case Jason.decode(cleaned) do
      {:ok, %{"results" => results}} when is_map(results) ->
        {:ok, parse_llm_results_map(results)}

      {:ok, _other} ->
        {:error, :invalid_llm_json_shape}

      {:error, reason} ->
        {:error, {:invalid_llm_json, reason}}
    end
  end

  # Parse the decoded JSON into an Elixir map
  defp parse_llm_results_map(results) do
    Enum.reduce(results, %{}, fn {entity_id_str, value}, acc ->
      case parse_single_llm_entity_result(entity_id_str, value) do
        {:ok, entity_id, parsed} ->
          Map.put(acc, entity_id, parsed)

        :error ->
          acc
      end
    end)
  end

  # Parse the LLM result for a single entity
  defp parse_single_llm_entity_result(entity_id_str, %{
        "best_index" => best_index,
        "descriptions" => descriptions
      })
      when is_integer(best_index) and is_map(descriptions) do
    case Integer.parse(to_string(entity_id_str)) do
      {entity_id, ""} ->
        normalized_descriptions =
          Enum.reduce(descriptions, %{}, fn {k, v}, acc ->
            case Integer.parse(to_string(k)) do
              {_idx, ""} ->
                Map.put(acc, to_string(k), to_string(v))

              _ ->
                acc
            end
          end)

        {:ok, entity_id,
        %{
          best_index: best_index,
          descriptions: normalized_descriptions
        }}

      _ ->
        :error
    end
  end

  defp parse_single_llm_entity_result(_entity_id_str, _value), do: :error

  defp strip_wrapping_code_fence(text) do
    text
    |> String.replace(~r/^```json\s*/i, "")
    |> String.replace(~r/^```\s*/i, "")
    |> String.replace(~r/\s*```$/, "")
    |> String.trim()
  end

  defp openai_config do
    Application.fetch_env!(:dsc, :openai)
  end

  defp openai_api_key do
    Keyword.fetch!(openai_config(), :api_key)
  end

  defp openai_base_url do
    Keyword.fetch!(openai_config(), :base_url)
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

  # -----------------------------
  # RESEARCH GROUP SENSOR CONFIGS
  # -----------------------------

  @doc """
  Lists every sensor config attached to a research group, enabled or not.

  Used by the researcher-facing group view, which needs to show disabled
  sensors so they can be re-enabled.
  """
  def list_group_sensor_configs(group_id) do
    from(sc in SensorConfig,
      where: sc.research_group_id == ^group_id,
      order_by: [asc: sc.type]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single sensor config scoped to a research group.

  Returns `nil` if the config does not belong to that group, which is what
  makes a cross-group id a 404 rather than an accidental read.
  """
  def get_group_sensor_config(group_id, sensor_config_id) do
    from(sc in SensorConfig,
      where: sc.research_group_id == ^group_id and sc.id == ^sensor_config_id,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Lists enabled sensor configs, their membership ids, and their group names for
  every study where the user is an active participant.

  Mirrors `list_participant_collectors/1`: the device stores the `membership_id`
  and echoes it back when uploading samples, which is what makes the data
  attributable to a study.

  Disabled configs are filtered out here so a device that never refetches still
  stops collecting when a researcher flips `enabled`.
  """
  def list_participant_sensor_configs(user_id) do
    from(sc in SensorConfig,
      join: m in ResearchGroupMembership,
      on: m.research_group_id == sc.research_group_id,
      join: rg in ResearchGroup,
      on: rg.id == m.research_group_id,
      where:
        m.user_id == ^user_id and
          is_nil(m.unenrolled_at) and
          m.role == "participant" and
          sc.enabled == true,
      select: {sc, m.id, rg.name},
      order_by: [asc: sc.type]
    )
    |> Repo.all()
  end

  @doc """
  Creates a sensor config for a research group.

  `group_id` comes from the route, not the body, so a request cannot target
  another study's config.
  """
  def create_sensor_config(group_id, %{} = attrs) do
    %SensorConfig{research_group_id: group_id}
    |> SensorConfig.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Applies a partial update to a sensor config. Only keys present in `attrs`
  are changed; `type` is fixed at creation.
  """
  def update_sensor_config(%SensorConfig{} = sensor_config, %{} = attrs) do
    sensor_config
    |> SensorConfig.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sensor config. Samples already collected under it are untouched;
  they are governed by the membership retention policy instead.
  """
  def delete_sensor_config(%SensorConfig{} = sensor_config) do
    Repo.delete(sensor_config)
  end
end
