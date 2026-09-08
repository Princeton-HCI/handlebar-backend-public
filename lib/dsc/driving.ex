defmodule DriversSeatCoop.Driving do
  @moduledoc """
  The Driving context.
  """

  import Ecto.Query, warn: false
  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Activities
  alias DriversSeatCoop.Activities.Activity
  alias DriversSeatCoop.Driving.Point
  alias DriversSeatCoop.Repo

  alias Ecto.Changeset

  require Logger

  @doc """
  Returns the list of points.

  ## Examples

      iex> list_points()
      [%Point{}, ...]

  """
  def list_points do
    Repo.all(Point)
  end

  @doc """
  Lists study-attributed location points, newest first, cursor paginated.

  Mirrors `Research.list_crepe_events/2` so the client can page location data
  the same way it pages screen data. Only points carrying a `membership_id` are
  returned — legacy Driver's Seat points have no study context and are not
  research data.

  Supported filters: `:membership_id`, `:group_id`, `:user_id`.

  Returns Point structs rather than a select map so cursor pagination keeps
  working; latitude and longitude are read off the `Geo.Point` geometry in the
  view rather than via ST_Y/ST_X here.
  """
  def list_study_points(filters \\ [], pagination_opts \\ %{}) do
    base_query =
      from(p in Point,
        join: m in DriversSeatCoop.Research.ResearchGroupMembership,
        on: m.id == p.membership_id,
        where: not is_nil(p.membership_id),
        order_by: [desc: p.recorded_at, desc: p.id]
      )
      |> apply_study_point_filters(filters)

    default_opts = %{
      cursor_fields: [{:recorded_at, :desc}, {:id, :desc}],
      limit: 50
    }

    Repo.paginate(base_query, Keyword.new(Map.merge(default_opts, pagination_opts)))
  end

  defp apply_study_point_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:membership_id, id}, q ->
        where(q, [p], p.membership_id == ^id)

      {:group_id, id}, q ->
        group_id = if is_binary(id), do: String.to_integer(id), else: id
        where(q, [p, m], m.research_group_id == ^group_id)

      {:user_id, id}, q ->
        where(q, [p], p.user_id == ^id)

      _, q ->
        q
    end)
  end

  def query_points_by_user_id(user_id, params \\ %{}) do
    query =
      from(p in Point,
        select: %{
          id: p.id,
          user_id: p.user_id,
          latitude: fragment("ST_Y(?)", p.geometry),
          longitude: fragment("ST_X(?)", p.geometry),
          recorded_at: p.recorded_at,
          device_id: p.device_id
        },
        where: p.user_id == ^user_id
      )

    date_start = Map.get(params, :date_start)
    date_end = Map.get(params, :date_end)
    limit = Map.get(params, :limit, nil)
    show_all_fields = Map.get(params, :show_all_fields, false)

    query =
      if show_all_fields do
        extra_fields = ~w(
          accuracy
          activity_confidence
          activity_type
          altitude
          battery_is_charging
          battery_level
          heading
          is_moving
          speed
          status
        )a

        query |> select_merge([p], map(p, ^extra_fields))
      else
        query
      end

    query =
      if is_nil(date_start) do
        query
      else
        query |> where([p], p.recorded_at >= ^date_start)
      end

    query =
      if is_nil(date_end) do
        query
      else
        query |> where([p], p.recorded_at < ^date_end)
      end

    query =
      if is_nil(limit) do
        query
      else
        query |> limit(^limit)
      end

    query
  end

  def list_points_by_user_id(user_id, params \\ %{}) do
    query_points_by_user_id(user_id, params)
    |> order_by(desc: :recorded_at)
    |> Repo.all()
  end

  @doc """
  Gets a single point.

  Raises `Ecto.NoResultsError` if the Point does not exist.

  ## Examples

      iex> get_point!(123)
      %Point{}

      iex> get_point!(456)
      ** (Ecto.NoResultsError)

  """
  def get_point!(id) do
    from(tp in Point,
      select_merge: %{
        latitude: fragment("ST_Y(?)", tp.geometry),
        longitude: fragment("ST_X(?)", tp.geometry)
      },
      where: tp.id == ^id
    )
    |> Repo.one!()
  end

  @doc """
  Creates a point.

  ## Examples

      iex> create_point(%{field: value})
      {:ok, %Point{}}

      iex> create_point(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_point(attrs, user_id) do
    %Point{user_id: user_id}
    |> Point.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Receives a list of maps and attempts to create a Point for each using `Ecto.Multi`.

  Points must be unique across [:user_id, :recorded_at]. Ecto upsert
  is used with the `:nothing` option to ignore any errors that occur
  when attempting to insert a Point when the user already has a Point at
  that time. An invalid point in the Ecto.Multi pipeline does not prevent other
  points from being created.
  """
  def create_points(attrs_list, user_id, device_id) when is_list(attrs_list) do
    multi = Ecto.Multi.new()

    Enum.with_index(attrs_list)
    |> Enum.reduce(multi, fn {attrs, index}, multi ->
      changeset =
        %Point{user_id: user_id, device_id: device_id}
        |> Point.changeset(attrs)

      # Ignore points that have an invalid changeset. This filters out bad
      # recorded_at times, invalid statuses, etc... Without causing the entire
      # request to fail.
      if changeset.valid? do
        # The on_conflict setting will cause non-unique points to be silently
        # filtered out
        Ecto.Multi.insert(multi, index, changeset,
          on_conflict: :nothing,
          conflict_target: [:user_id, :recorded_at]
        )
      else
        Logger.warn("failed to create point #{inspect(changeset)}")

        multi
      end
    end)
    |> Repo.transaction()
    |> case do
      # cleanup error response
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
      res -> res
    end
  end

  @doc """
  Updates a point.

  ## Examples

      iex> update_point(point, %{field: new_value})
      {:ok, %Point{}}

      iex> update_point(point, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_point(%Point{} = point, attrs) do
    point
    |> Point.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking point changes.

  ## Examples

      iex> change_point(point)
      %Ecto.Changeset{source: %Point{}}

  """
  def change_point(%Point{} = point) do
    Point.changeset(point, %{})
  end

  def get_activity(id), do: Repo.get(Activity, id)

  def list_activity_ids_by_user_id(user_id) do
    from(a in Activity, select: a.activity_id, where: [user_id: ^user_id, deleted: false])
    |> Repo.all()
  end

  def upsert_activity(activity_data, user_id, deleted \\ false) do
    date = activity_data["start_date"] || activity_data["end_date"]

    date =
      if is_nil(date) do
        nil
      else
        NaiveDateTime.from_iso8601!(date)
      end

    user = Accounts.get_user!(user_id)

    activity_id = activity_data["id"]
    original_activity = Activities.get_activity_by_activity_id(activity_id)
    activity = original_activity || %Activity{user_id: user_id, activity_id: activity_id}

    activity_params =
      extract_activity_fields(activity_data)
      |> Map.merge(%{
        activity_id: activity_id,
        user_id: user_id,
        activity_data: activity_data,
        date: date,
        deleted: deleted
      })

    changeset = Activity.changeset(activity, user, activity_params)

    {:ok, activity} = upsert_activity_impl(changeset, original_activity)

    Activities.update_activity_hours(activity, user)

    {:ok, activity}
  end

  # credo:disable-for-next-line
  defp upsert_activity_impl(changeset, nil = _original_activity) do
    # if no value > 0,
    changeset =
      cond do
        (Changeset.get_field(changeset, :earnings_pay_cents, 0) || 0) > 0 ->
          Changeset.put_change(changeset, :notification_required, true)

        (Changeset.get_field(changeset, :earnings_tip_cents, 0) || 0) > 0 ->
          Changeset.put_change(changeset, :notification_required, true)

        (Changeset.get_field(changeset, :earnings_bonus_cents, 0) || 0) > 0 ->
          Changeset.put_change(changeset, :notification_required, true)

        (Changeset.get_field(changeset, :earnings_total_cents, 0) || 0) > 0 ->
          Changeset.put_change(changeset, :notification_required, true)

        true ->
          Changeset.put_change(changeset, :notification_required, false)
      end

    Repo.insert(changeset,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :activity_id
    )
  end

  # credo:disable-for-next-line
  defp upsert_activity_impl(changeset, activity) do
    changeset =
      cond do
        # if deleted activity, we never want to notify
        Changeset.get_field(changeset, :deleted, false) ->
          Changeset.put_change(changeset, :notification_required, false)

        # if any of these fields changed, set to true
        (Changeset.get_field(changeset, :earnings_pay_cents, 0) || 0) !=
            (activity.earnings_pay_cents || 0) ->
          Changeset.put_change(changeset, :notification_required, true)

        (Changeset.get_field(changeset, :earnings_tip_cents, 0) || 0) !=
            (activity.earnings_tip_cents || 0) ->
          Changeset.put_change(changeset, :notification_required, true)

        (Changeset.get_field(changeset, :earnings_bonus_cents, 0) || 0) !=
            (activity.earnings_bonus_cents || 0) ->
          Changeset.put_change(changeset, :notification_required, true)

        (Changeset.get_field(changeset, :earnings_total_cents, 0) || 0) !=
            (activity.earnings_total_cents || 0) ->
          Changeset.put_change(changeset, :notification_required, true)

        true ->
          Changeset.put_change(
            changeset,
            :notification_required,
            activity.notification_required || false
          )
      end

    Repo.update(changeset)
  end

  def delete_activities(activity_ids) do
    activity_ids = List.wrap(activity_ids)

    # do a soft delete of all the provided activity ids
    from(a in Activity, where: a.activity_id in ^activity_ids)
    |> Repo.update_all(set: [deleted: true, notification_required: false])
  end

  defp extract_activity_fields(activity_data) do
    %{}
    |> try_map_raw_value(activity_data, "type", :service_class)
    |> try_map_raw_value(activity_data, "employer", :employer)
    |> try_map_raw_value(activity_data, ["circumstances", "service_type"], :employer_service)
    |> try_map_raw_value(activity_data, "data_partner", :data_partner)
    |> try_map_raw_value(activity_data, "earning_type", :earning_type)
    |> try_map_raw_value(activity_data, "status", :status)
    |> try_map_boolean(activity_data, ["circumstances", "is_pool"], :is_pool)
    |> try_map_boolean(activity_data, ["circumstances", "is_rush"], :is_rush)
    |> try_map_boolean(activity_data, ["circumstances", "is_surge"], :is_surge)
    |> try_map_money_as_cents(activity_data, ["income_rates", "mile"], :income_rate_mile_cents)
    |> try_map_money_as_cents(activity_data, ["income_rates", "hour"], :income_rate_hour_cents)
    |> try_map_raw_value(activity_data, ["income", "currency"], :currency)
    |> try_map_money_as_cents(activity_data, ["income", "pay"], :earnings_pay_cents)
    |> try_map_money_as_cents(activity_data, ["income", "tips"], :earnings_tip_cents)
    |> try_map_money_as_cents(activity_data, ["income", "bonus"], :earnings_bonus_cents)
    |> try_map_money_as_cents(activity_data, ["income", "total"], :earnings_total_cents)
    |> try_map_money_as_cents(activity_data, ["income", "fees"], :charges_fees_cents)
    |> try_map_money_as_cents(activity_data, ["income", "taxes"], :charges_taxes_cents)
    |> try_map_money_as_cents(activity_data, ["income", "total_charge"], :charges_total_cents)
    |> try_map_decimal(activity_data, "distance", :distance)
    |> try_map_raw_value(activity_data, "distance_unit", :distance_unit)
    |> try_map_integer(activity_data, "duration", :duration_seconds)
    |> try_map_integer(activity_data, "num_tasks", :tasks_total)
    |> try_map_raw_value(activity_data, "timezone", :timezone)
    |> try_map_timestamp(activity_data, "start_date", :timestamp_start)
    |> try_map_timestamp(activity_data, ["all_datetimes", "request_at"], :timestamp_request)
    |> try_map_timestamp(activity_data, ["all_datetimes", "accept_at"], :timestamp_accept)
    |> try_map_timestamp(activity_data, ["all_datetimes", "cancel_at"], :timestamp_cancel)
    |> try_map_timestamp(activity_data, ["all_datetimes", "pickup_at"], :timestamp_pickup)
    |> try_map_timestamp(activity_data, ["all_datetimes", "dropoff_at"], :timestamp_dropoff)
    |> try_map_timestamp(activity_data, ["all_datetimes", "shift_start"], :timestamp_shift_start)
    |> try_map_timestamp(activity_data, ["all_datetimes", "shift_end"], :timestamp_shift_end)
    |> try_map_timestamp(activity_data, "end_date", :timestamp_end)
    |> try_map_float(activity_data, ["start_location", "lat"], :start_location_lat)
    |> try_map_float(activity_data, ["start_location", "lng"], :start_location_lon)
    |> try_map_raw_value(
      activity_data,
      ["start_location", "formatted_address"],
      :start_location_address
    )
    |> try_map_float(activity_data, ["end_location", "lat"], :end_location_lat)
    |> try_map_float(activity_data, ["end_location", "lng"], :end_location_lon)
    |> try_map_raw_value(
      activity_data,
      ["end_location", "formatted_address"],
      :end_location_address
    )
  end

  def try_map_raw_value(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    Map.put(map, to_property, raw_val)
  end

  defp try_map_decimal(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    cond do
      is_nil(raw_val) ->
        Map.put(map, to_property, nil)

      is_float(raw_val) ->
        Map.put(map, to_property, Decimal.from_float(raw_val))

      Decimal.parse(raw_val) == :error ->
        Map.put(map, to_property, nil)

      true ->
        {val, _} = Decimal.parse(raw_val)
        Map.put(map, to_property, val)
    end
  end

  defp try_map_float(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    cond do
      is_nil(raw_val) ->
        Map.put(map, to_property, nil)

      is_float(raw_val) ->
        Map.put(map, to_property, raw_val)

      Float.parse(raw_val) == :error ->
        Map.put(map, to_property, nil)

      true ->
        {val, _} = Float.parse(raw_val)
        Map.put(map, to_property, val)
    end
  end

  defp try_map_integer(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    cond do
      is_nil(raw_val) ->
        Map.put(map, to_property, nil)

      is_integer(raw_val) ->
        Map.put(map, to_property, raw_val)

      Integer.parse(raw_val) == :error ->
        Map.put(map, to_property, nil)

      true ->
        {val, _} = Integer.parse(raw_val)
        Map.put(map, to_property, val)
    end
  end

  defp try_map_money_as_cents(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    cond do
      is_nil(raw_val) ->
        Map.put(map, to_property, nil)

      is_float(raw_val) ->
        Map.put(
          map,
          to_property,
          Decimal.from_float(raw_val)
          |> Decimal.mult(100)
          |> Decimal.round()
          |> Decimal.to_integer()
        )

      Decimal.parse(raw_val) == :error ->
        Map.put(map, to_property, nil)

      true ->
        {val, _} = Decimal.parse(raw_val)

        val =
          val
          |> Decimal.mult(100)
          |> Decimal.round()
          |> Decimal.to_integer()

        Map.put(map, to_property, val)
    end
  end

  defp try_map_boolean(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    case raw_val do
      val when val in [true, "true"] ->
        Map.put(map, to_property, true)

      val when val in [false, "false"] ->
        Map.put(map, to_property, false)

      _ ->
        Map.put(map, to_property, nil)
    end
  end

  defp try_map_timestamp(map, source_map, source_path, to_property) do
    source_path = List.wrap(source_path)

    raw_val = get_in(source_map, source_path)

    if is_nil(raw_val) do
      Map.put(map, to_property, nil)
    else
      case NaiveDateTime.from_iso8601(raw_val) do
        {:ok, val} ->
          Map.put(map, to_property, val)

        _ ->
          Map.put(map, to_property, nil)
      end
    end
  end

  def delete_points_query_batch(qry, batch_size \\ 1000) do
    ids =
      from(p in qry, select: p.id, limit: ^batch_size)
      |> Repo.all()

    if Enum.any?(ids) do
      from(p in Point, where: p.id in ^ids)
      |> Repo.delete_all(timeout: :infinity)
    end

    count_ids = Enum.count(ids)

    if count_ids == batch_size,
      do: count_ids + delete_points_query_batch(qry, batch_size),
      else: count_ids
  end
end
