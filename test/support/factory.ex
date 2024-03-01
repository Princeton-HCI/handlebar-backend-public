defmodule DriversSeatCoop.Factory do
  import Ecto.Query, warn: false
  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Activities
  alias DriversSeatCoop.Activities.Activity
  alias DriversSeatCoop.Devices
  alias DriversSeatCoop.Driving
  alias DriversSeatCoop.Employers.Employer
  alias DriversSeatCoop.Employers.ServiceClass
  alias DriversSeatCoop.Expenses
  alias DriversSeatCoop.Goals
  alias DriversSeatCoop.Goals.Goal
  alias DriversSeatCoop.Goals.GoalMeasurement
  alias DriversSeatCoop.Legal
  alias DriversSeatCoop.Regions.County
  alias DriversSeatCoop.Regions.MetroArea
  alias DriversSeatCoop.Regions.PostalCode
  alias DriversSeatCoop.Regions.State
  alias DriversSeatCoop.Repo
  alias DriversSeatCoop.Research
  alias DriversSeatCoop.ScheduledShifts
  alias DriversSeatCoop.Shifts
  alias DriversSeatCoop.Util.DateTimeUtil

  def create_admin_user(attrs \\ %{}) do
    valid_attrs = %{
      email: "email#{:erlang.monotonic_time()}@example.com",
      password: "password",
      service_names: ["food"],
      vehicle_make: "Toyota",
      vehicle_model: "Camry",
      vehicle_type: "car",
      vehicle_year: 2019,
      role: "admin"
    }

    {:ok, user} =
      attrs
      |> Enum.into(valid_attrs)
      |> Accounts.admin_create_user()

    user
  end

  @doc """
  forced_attrs are values set after the changeset has been applied
  """
  def create_user(attrs \\ %{}, forced_attrs \\ %{}) do
    valid_attrs = %{
      email: "email#{:erlang.monotonic_time()}@example.com",
      password: "password",
      service_names: ["food"],
      vehicle_make: "Toyota",
      vehicle_model: "Camry",
      vehicle_type: "car",
      vehicle_year: 2019
    }

    attrs = Enum.into(attrs, valid_attrs)

    {:ok, user} = Accounts.create_user(attrs)

    update_vals =
      [
        inserted_at: Map.get(attrs, "inserted_at", user.inserted_at),
        updated_at: Map.get(attrs, "updated_at", user.updated_at)
      ] ++ Enum.to_list(forced_attrs)

    # this allows us to manipulate values that are programatically set without
    # exposing this in our context functions
    from(u in User,
      where: u.id == ^user.id
    )
    |> Repo.update_all(set: update_vals)

    Accounts.get_user!(user.id)
  end

  def create_deleted_user(attrs \\ %{}) do
    user = create_user(attrs)
    Accounts.delete_user(user)
    user
  end

  defp fetch_or_create_user_id(attrs) do
    case Map.fetch(attrs, :user_id) do
      {:ok, id} ->
        id

      :error ->
        user = create_user()
        user.id
    end
  end

  def create_user_with_argyle_fields(attrs \\ %{}) do
    valid_attrs = %{
      argyle_user_id: "id",
      argyle_token: "token",
      argyle_accounts: nil,
      service_names: nil
    }

    user =
      fetch_or_create_user_id(attrs)
      |> Accounts.get_user!()

    {:ok, argyle_user} = Accounts.update_user(user, Enum.into(attrs, valid_attrs))

    argyle_user
  end

  def create_point(attrs \\ %{}) do
    valid_attrs = %{
      latitude: 43,
      longitude: -89,
      recorded_at: NaiveDateTime.utc_now(),
      status: "working"
    }

    attrs = Enum.into(attrs, valid_attrs)

    user_id = fetch_or_create_user_id(attrs)

    {:ok, point} = Driving.create_point(attrs, user_id)

    point
  end

  def create_research_group(attrs \\ %{}) do
    valid_attrs = %{
      name: "Research",
      description: "Describing the group",
      code: "rsrch"
    }

    {:ok, research_group} =
      attrs
      |> Enum.into(valid_attrs)
      |> Research.create_research_group()

    research_group
  end

  def create_terms(attrs \\ %{}) do
    valid_attrs = %{
      title: "Terms #1",
      text: "Text of legal terms\n",
      required_at: DateTime.utc_now()
    }

    user_id = fetch_or_create_user_id(attrs)

    {:ok, terms} =
      attrs
      |> Enum.into(valid_attrs)
      |> Legal.create_terms(user_id)

    terms
  end

  def create_accepted_terms(attrs \\ %{}) do
    valid_attrs = %{}

    accepted_at =
      case Map.fetch(attrs, :accepted_at) do
        {:ok, accepted_at} ->
          accepted_at

        :error ->
          NaiveDateTime.utc_now()
      end

    user_id = fetch_or_create_user_id(attrs)

    valid_attrs =
      case Map.fetch(attrs, :terms_id) do
        {:ok, _id} ->
          valid_attrs

        :error ->
          terms = create_terms()
          Map.put(valid_attrs, :terms_id, terms.id)
      end

    {:ok, accepted_terms} =
      attrs
      |> Enum.into(valid_attrs)
      |> Legal.create_accepted_terms(user_id, accepted_at)

    accepted_terms
  end

  def create_expense(attrs \\ %{}) do
    valid_attrs = %{
      category: "Gas",
      name: "Name",
      date: Date.utc_today(),
      money: 1_099
    }

    user_id = fetch_or_create_user_id(attrs)

    {:ok, expense} =
      attrs
      |> Enum.into(valid_attrs)
      |> Expenses.create_expense(user_id)

    expense
  end

  def create_device(user_id, device_id, attrs \\ %{}) do
    Devices.get_or_update!(user_id, device_id, attrs)
  end

  def create_shift(attrs \\ %{}) do
    user_id = fetch_or_create_user_id(attrs)

    device_id = Map.get(attrs, :device_id)

    valid_attrs = %{start_time: "2021-06-20T00:53:16Z"}

    attrs = Enum.into(attrs, valid_attrs)

    {:ok, shift} =
      attrs
      |> Shifts.create_shift(user_id, device_id)

    shift
  end

  def create_scheduled_shifts(user_id, attrs_list \\ []) do
    {:ok, scheduled_shifts} = ScheduledShifts.update_scheduled_shifts(attrs_list, user_id)
    scheduled_shifts
  end

  def create_earnings_goal(
        user_id,
        amount \\ 10_000,
        frequency \\ :day,
        start_date \\ Date.add(Date.utc_today(), -7)
      ) do
    {:ok, result} =
      Goals.update_goals(
        user_id,
        :earnings,
        frequency,
        start_date,
        %{
          "all" => amount
        },
        nil
      )

    result
  end

  # credo:disable-for-next-line
  def create_activity(
        %User{} = user,
        %Employer{} = employer,
        %ServiceClass{} = service_class,
        %NaiveDateTime{} = start_time_local,
        %NaiveDateTime{} = end_time_local,
        earnings,
        miles,
        count_tasks \\ 1,
        %NaiveDateTime{} = accept_time_local \\ nil
      ) do
    start_time_utc =
      DateTime.from_naive!(start_time_local, user.timezone)
      |> DateTime.shift_zone!("Etc/UTC")

    end_time_utc =
      DateTime.from_naive!(end_time_local, user.timezone)
      |> DateTime.shift_zone!("Etc/UTC")

    accept_time_utc =
      DateTime.from_naive!(accept_time_local, user.timezone)
      |> DateTime.shift_zone!("Etc/UTC")

    attrs = %{
      "employer" => employer.name,
      "type" => service_class.name,
      "timezone" => user.timezone,
      "earning_type" => "work",
      "status" => "completed",
      "pay" => earnings,
      "total" => earnings,
      "accept_at" => accept_time_utc,
      "distance" => miles,
      "distance_unit" => "miles",
      "num_tasks" => count_tasks,
      "start_date" => start_time_utc,
      "end_date" => end_time_utc
    }

    create_activity(user.id, attrs, false)
  end

  @doc """
  Create activities without filtering or assuming values
  """
  def create_activity(user_id, attrs, deleted \\ nil) do
    activity_data = %{
      "id" => Map.get(attrs, "activity_id", Ecto.UUID.generate()),
      "data_partner" => Map.get(attrs, "employer"),
      "distance" => Map.get(attrs, "distance"),
      "distance_units" => Map.get(attrs, "distance_units"),
      "duration" => Map.get(attrs, "duration"),
      "earning_type" => Map.get(attrs, "earning_type"),
      "employer" => Map.get(attrs, "employer"),
      "type" => Map.get(attrs, "type"),
      "num_tasks" => Map.get(attrs, "num_tasks"),
      "status" => Map.get(attrs, "status"),
      "start_date" => Map.get(attrs, "start_date") |> to_iso8601(),
      "end_date" => Map.get(attrs, "end_date") |> to_iso8601(),
      "all_timestamps" => %{
        "break_end" => Map.get(attrs, "break_end") |> to_unix(),
        "break_start" => Map.get(attrs, "break_start") |> to_unix(),
        "cancel_at" => Map.get(attrs, "cancel_at") |> to_unix(),
        "accept_at" => Map.get(attrs, "accept_at") |> to_unix(),
        "dropoff_at" => Map.get(attrs, "dropoff_at") |> to_unix(),
        "pickup_at" => Map.get(attrs, "pickup_at") |> to_unix(),
        "request_at" => Map.get(attrs, "request_at") |> to_unix(),
        "shift_end" => Map.get(attrs, "shift_end") |> to_unix(),
        "shift_start" => Map.get(attrs, "shift_start") |> to_unix()
      },
      "all_datetimes" => %{
        "break_end" => Map.get(attrs, "break_end") |> to_iso8601(),
        "break_start" => Map.get(attrs, "break_start") |> to_iso8601(),
        "cancel_at" => Map.get(attrs, "cancel_at") |> to_iso8601(),
        "accept_at" => Map.get(attrs, "accept_at") |> to_iso8601(),
        "dropoff_at" => Map.get(attrs, "dropoff_at") |> to_iso8601(),
        "pickup_at" => Map.get(attrs, "pickup_at") |> to_iso8601(),
        "request_at" => Map.get(attrs, "request_at") |> to_iso8601(),
        "shift_end" => Map.get(attrs, "shift_end") |> to_iso8601(),
        "shift_start" => Map.get(attrs, "shift_start") |> to_iso8601()
      },
      "income" => %{
        "currency" => Map.get(attrs, "currency"),
        "pay" => Map.get(attrs, "pay"),
        "tips" => Map.get(attrs, "tips"),
        "bonus" => Map.get(attrs, "bonus"),
        "total" => Map.get(attrs, "total")
      },
      "timezone" => Map.get(attrs, "timezone")
    }

    {:ok, activity} =
      Driving.upsert_activity(
        activity_data,
        user_id,
        deleted || Map.get(attrs, "deleted") || false
      )

    # this allows us to manipulate vlaues that are programatically set without
    # exposing this in our context functions
    from(activity in Activity,
      where: activity.id == ^activity.id
    )
    |> Repo.update_all(
      set: [
        deleted: Map.get(attrs, "deleted", activity.deleted),
        notification_required:
          Map.get(attrs, "notification_required", activity.notification_required),
        notified_on: Map.get(attrs, "notified_on", activity.notified_on),
        inserted_at: Map.get(attrs, "inserted_at", activity.inserted_at),
        updated_at: Map.get(attrs, "updated_at", activity.updated_at)
      ]
    )

    Activities.get_activity(activity.user_id, activity.id)
  end

  defp to_iso8601(nil) do
    nil
  end

  defp to_iso8601(dtm) do
    DateTime.to_iso8601(dtm)
  end

  defp to_unix(nil) do
    nil
  end

  defp to_unix(dtm) do
    DateTime.to_unix(dtm)
  end

  def create_activity(attrs \\ %{}) do
    user_id = Map.get(attrs, "user_id") || create_user().id

    start_date = Map.get(attrs, "date") || Map.get(attrs, "start_date", ~U[2021-06-26T03:39:18Z])

    end_date = Map.get(attrs, "end_date", DateTime.add(start_date, 60 * 30))

    request_date = Map.get(attrs, "request_date", DateTime.add(start_date, -60 * 2))

    activity_id = Ecto.UUID.generate()

    timezone = Map.get(attrs, "timezone", "America/New_York")

    activity_data = %{
      "id" => activity_id,
      "data_partner" => "uber_eats",
      "distance" => "10.0",
      "distance_units" => "miles",
      "duration" => DateTime.diff(end_date, start_date),
      "earning_type" => "work",
      "employer" => "uber",
      "num_tasks" => Map.get(attrs, "num_tasks") || 1,
      "status" => "completed",
      "start_date" => start_date |> DateTime.to_iso8601(),
      "end_date" => end_date |> DateTime.to_iso8601(),
      "all_timestamps" => %{
        "break_end" => nil,
        "break_start" => nil,
        "dropoff_at" => end_date |> DateTime.to_unix(),
        "pickup_at" => start_date |> DateTime.to_unix(),
        "request_at" => request_date |> DateTime.to_unix(),
        "shift_end" => nil,
        "shift_start" => nil
      },
      "all_datetimes" => %{
        "dropoff_at" => end_date |> DateTime.to_iso8601(),
        "pickup_at" => start_date |> DateTime.to_iso8601(),
        "request_at" => request_date |> DateTime.to_iso8601()
      },
      "income" => %{
        "currency" => "USD",
        "pay" => "5.00",
        "tips" => "2.15",
        "bonus" => nil
      },
      "timezone" => timezone
    }

    deleted = Map.get(attrs, "deleted", false)

    {:ok, activity} = Driving.upsert_activity(activity_data, user_id, deleted)

    # this allows us to manipulate vlaues that are programatically set without
    # exposing this in our context functions
    from(activity in Activity,
      where: activity.id == ^activity.id
    )
    |> Repo.update_all(
      set: [
        notification_required:
          Map.get(attrs, :notification_required, activity.notification_required),
        notified_on: Map.get(attrs, :notified_on, activity.notified_on),
        inserted_at: Map.get(attrs, :inserted_at, activity.inserted_at),
        updated_at: Map.get(attrs, :updated_at, activity.updated_at)
      ]
    )

    Activities.get_activity(activity.user_id, activity.id)
  end

  def create_work_activity(user, date, amount_cents, employer \\ "uber") do
    [start_time, _end_time] = User.working_day_bounds(date, user)

    create_activity(
      user.id,
      %{
        "timezone" => user.timezone,
        "employer" => employer,
        "earning_type" => "work",
        "status" => "completed",
        "num_tasks" => 1,
        "start_date" => DateTime.add(start_time, 600, :second),
        "end_date" => DateTime.add(start_time, 1_200, :second),
        "pay" =>
          Decimal.new(amount_cents)
          |> Decimal.div(100)
          |> Decimal.to_string(),
        "total" =>
          Decimal.new(amount_cents)
          |> Decimal.div(100)
          |> Decimal.to_string()
      },
      false
    )
  end

  def create_incentive_activity(user, date, amount_cents, employer \\ "uber") do
    [start_time, _end_time] = User.working_day_bounds(date, user)

    create_activity(
      user.id,
      %{
        "timezone" => user.timezone,
        "employer" => employer,
        "earning_type" => "incentive",
        "status" => "completed",
        "num_tasks" => 0,
        "start_date" => start_time,
        "end_date" => start_time,
        "bonus" =>
          Decimal.new(amount_cents)
          |> Decimal.div(100)
          |> Decimal.to_string(),
        "total" =>
          Decimal.new(amount_cents)
          |> Decimal.div(100)
          |> Decimal.to_string()
      },
      false
    )
  end

  def create_default_goal(user_id, type, frequency, start_date, amount) do
    Goals.update_goals(user_id, type, frequency, start_date, %{"all" => amount}, nil)

    {start_date, _} = DateTimeUtil.get_time_window_for_date(start_date, frequency)

    Goals.query_goals()
    |> Goals.query_goals_filter_user(user_id)
    |> Goals.query_goals_filter_type(type)
    |> Goals.query_goals_filter_frequency(frequency)
    |> Goals.query_goals_filter_start_date(start_date)
    |> Repo.all()
    |> Enum.at(0)
  end

  def create_goal_measurement(
        %Goal{} = goal,
        %Date{} = date,
        performance_amount,
        additional_info \\ %{}
      ) do
    performance_percent = Decimal.from_float(performance_amount / goal.amount)

    # normalize the performance date to the start date
    {date, _} = DateTimeUtil.get_time_window_for_date(date, goal.frequency)

    performance = %{
      user_id: goal.user_id,
      goal_id: goal.id,
      performance_amount: performance_amount,
      performance_percent: performance_percent,
      window_date: date,
      additional_info: additional_info
    }

    changeset =
      GoalMeasurement.changeset(
        %GoalMeasurement{user_id: goal.user_id, goal_id: goal.id},
        performance
      )

    {:ok, goal_measurement} =
      Repo.insert(changeset,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:goal_id, :window_date]
      )

    goal_measurement
  end

  @geometry Geo.JSON.encode(%Geo.Point{coordinates: {-86.232688, 34.614731}, srid: 4326})

  def create_metro_area(id, attrs \\ %{}) do
    attrs =
      %{
        name: "Metro Area #{id}",
        full_name: "Metro Area #{id}",
        geometry: @geometry
      }
      |> Map.merge(attrs)
      |> Map.put(:id, id)

    metro = %MetroArea{
      id: Map.get(attrs, :id)
    }

    metro =
      MetroArea.sync_changeset(metro, attrs)
      |> Repo.insert_or_update!()

    MetroArea.stats_changeset(metro, attrs)
    |> Repo.insert_or_update!()
    |> Map.put(:geometry, nil)
  end

  def create_state(id, attrs \\ %{}) do
    attrs =
      %{
        name: "State #{id}",
        abbrv: "State #{id}",
        geometry: @geometry
      }
      |> Map.merge(attrs)
      |> Map.put(:id, id)

    state = %State{
      id: Map.get(attrs, :id)
    }

    State.sync_changeset(state, attrs)
    |> Repo.insert_or_update!()
    |> Map.put(:geometry, nil)
  end

  def create_county(id, state_id, attrs \\ %{}) do
    attrs =
      %{
        name: "county #{id}",
        region_id_state: state_id,
        geometry: @geometry
      }
      |> Map.merge(attrs)
      |> Map.put(:id, id)

    county = %County{
      id: Map.get(attrs, :id)
    }

    County.sync_changeset(county, attrs)
    |> Repo.insert_or_update!()
    |> Map.put(:geometry, nil)
  end

  def create_postal_code(id, postal_code, county_id, state_id, metro_area_id \\ nil) do
    attrs = %{
      id: id,
      postal_code: postal_code,
      region_id_county: county_id,
      region_id_state: state_id,
      region_id_metro_area: metro_area_id,
      geometry: @geometry
    }

    postal_code = %PostalCode{
      id: id
    }

    PostalCode.sync_changeset(postal_code, attrs)
    |> Repo.insert_or_update!()
    |> Map.put(:geometry, nil)
  end
end
