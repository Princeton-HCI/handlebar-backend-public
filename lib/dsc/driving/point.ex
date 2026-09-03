defmodule DriversSeatCoop.Driving.Point do
  use Ecto.Schema
  import Ecto.Changeset

  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Devices.Device
  alias DriversSeatCoop.Research.ResearchGroupMembership

  @valid_statuses ~w(working not_working)

  # NOTE: user_id is omitted from both of these field sets and manually added
  # below in the changeset function
  @required_fields ~w(
    latitude
    longitude
    recorded_at
    status
  )a
  @optional_fields ~w(
    accuracy
    activity_confidence
    activity_type
    altitude
    battery_is_charging
    battery_level
    heading
    is_moving
    membership_id
    speed
  )a

  schema "points" do
    field :recorded_at, :utc_datetime_usec

    field :accuracy, :float
    field :activity_confidence, :float
    field :activity_type, :string
    field :altitude, :float
    field :battery_is_charging, :boolean
    field :battery_level, :float
    field :geometry, Geo.PostGIS.Geometry
    field :heading, :float
    field :is_moving, :boolean
    field :latitude, :float, virtual: true
    field :longitude, :float, virtual: true
    field :speed, :float
    field :status, :string

    belongs_to(:user, User)
    belongs_to(:device, Device)

    # Which study this point was collected for. nil for legacy Driver's Seat
    # points, which have no study context. PointController verifies that a
    # body-supplied membership_id is actually owned by the caller.
    belongs_to(:membership, ResearchGroupMembership)

    timestamps()
  end

  @doc false
  def changeset(point, attrs) do
    # NOTE: user_id is not cast here. It is set explicitly in
    # Driving.create_point and not provided in HTTP requests
    point
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields ++ [:user_id])
    # limit latitude & longitude to coordinates are valid
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> cast_geometry()
    |> assoc_constraint(:user)
    |> assoc_constraint(:device)
    |> assoc_constraint(:membership)
    |> validate_inclusion(:status, @valid_statuses)
    |> check_recorded_at()
    |> unique_constraint(:recorded_at, name: :points_user_id_recorded_at_index)
  end

  defp check_recorded_at(%{valid?: false} = changeset), do: changeset

  defp check_recorded_at(changeset) do
    # Sometimes the app sends a point with a recorded_at around the time of the
    # UNIX epoch, presumably due to a bug with the phone itself. It has only
    # occurred on Android devices so far. A Sentry message is sent, but it's
    # rare and typically no action is taken. This function filters out those
    # bad timestamps.

    recorded_at = get_change(changeset, :recorded_at)

    if not is_nil(recorded_at) && Date.compare(recorded_at, ~D[2019-01-01]) == :lt do
      add_error(changeset, :recorded_at, "cannot be before 2019")
    else
      changeset
    end
  end

  def cast_geometry(%{valid?: false} = changeset), do: changeset

  def cast_geometry(changeset) do
    latitude = get_change(changeset, :latitude)
    longitude = get_change(changeset, :longitude)
    json = Geo.JSON.encode(%Geo.Point{coordinates: {longitude, latitude}, srid: 4326})

    cast(changeset, %{geometry: json}, [:geometry])
  end
end
