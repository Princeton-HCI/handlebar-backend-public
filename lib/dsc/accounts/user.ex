defmodule DriversSeatCoop.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias DriversSeatCoop.Regions
  alias DriversSeatCoop.Util.DateTimeUtil

  @not_avail :not_in_changeset
  @valid_app_channels ["alpha", "beta", "prod"]
  @valid_roles ["admin"]
  @valid_vehicle_types ["bike", "car", "e-bike", "moped", "rickshaw"]
  @working_day_end_time ~T[04:00:00]
  @required_fields ~w(email)a

  # NOTE: role is set through a separate changeset to prevent normal requests
  # from changing it.
  @optional_fields ~w(
    argyle_accounts
    argyle_token
    argyle_user_id
    car_ownership
    contact_permission
    country
    country_argyle
    deleted
    device_platform
    engine_type
    enrolled_research_at
    ethnicity
    first_name
    focus_group
    gender
    gender_argyle
    is_demo_account
    is_beta
    last_name
    opted_out_of_data_sale_at
    opted_out_of_sensitive_data_use_at
    opted_out_of_push_notifications
    password
    phone_number
    postal_code
    postal_code_argyle
    referral_code
    remind_shift_end
    remind_shift_start
    service_names
    source
    timezone
    timezone_argyle
    timezone_device
    unenrolled_research_at
    vehicle_make
    vehicle_make_argyle
    vehicle_model
    vehicle_model_argyle
    vehicle_type
    vehicle_year
    vehicle_year_argyle
    metro_area_id
  )a

  schema "users" do
    field :email, :string

    field :first_name, :string
    field :last_name, :string
    field :phone_number, :string

    field :vehicle_make, :string
    field :vehicle_make_argyle, :string
    field :vehicle_model, :string
    field :vehicle_model_argyle, :string
    field :vehicle_type, :string
    field :vehicle_year, :integer
    field :vehicle_year_argyle, :integer

    field :contact_permission, :boolean
    field :device_platform, :string
    field :focus_group, :string
    field :service_names, {:array, :string}
    field :engine_type, :string
    field :country, :string
    field :country_argyle, :string
    field :postal_code, :string
    field :postal_code_argyle, :string
    field :opted_out_of_data_sale_at, :naive_datetime_usec
    field :opted_out_of_sensitive_data_use_at, :naive_datetime_usec
    field :car_ownership, :string

    field :enrolled_research_at, :naive_datetime_usec
    field :unenrolled_research_at, :naive_datetime_usec

    field :role, :string
    field :ethnicity, {:array, :string}

    field :password_hash, :string

    field :reset_password_token, :string
    field :reset_password_token_expires_at, :naive_datetime_usec

    field :gender, :string, default: nil
    field :gender_argyle, :string, default: nil
    field :opted_out_of_push_notifications, :boolean, default: false

    # NOTE: the name of this field would imply that it's a boolean, but it is
    # not. it actually stores the app distribution channel that the user is on
    # TODO: rename this field so it makes sense
    field :is_beta, :string, default: "prod"

    field :source, :string, default: "web"
    field :deleted, :boolean, default: false

    field :password, :string, virtual: true
    field :referral_code, :string, virtual: true

    # timezone provided by user, overrides timezone_device and timezone_argyle
    field :timezone, :string

    # timezone taken from the user's device, backup if user-provided timezone is
    # missing
    field :timezone_device, :string

    # timezone from processing argyle activities in a batch job, backup if all
    # other timezone fields are missing
    field :timezone_argyle, :string

    # fields used by argyle_user endpoint
    field :argyle_accounts, :map
    field :argyle_token, :string
    field :argyle_user_id, :string

    # fields used to remind users to start/stop shifts
    field :remind_shift_start, :boolean, default: false
    field :remind_shift_end, :boolean, default: false

    belongs_to :metro_area, DriversSeatCoop.Regions.MetroArea
    belongs_to :referral_source, DriversSeatCoop.ReferralSource
    has_many :crepe_events, DriversSeatCoop.Crepe.CrepeEvent

    field :is_demo_account, :boolean, default: false

    timestamps()
  end

  def can_receive_notification(user) do
    not (user.opted_out_of_push_notifications or user.deleted)
  end

  def can_receive_start_shift_notification(user) do
    user.remind_shift_start and can_receive_notification(user)
  end

  def can_receive_end_shift_notification(user) do
    user.remind_shift_end and can_receive_notification(user)
  end

  def has_profile?(user) do
    not is_nil(user.first_name) and not is_nil(user.last_name)
  end

  def valid_roles, do: @valid_roles
  def valid_vehicle_types, do: @valid_vehicle_types
  def valid_app_channels, do: @valid_app_channels

  def has_argyle_linked?(%{argyle_user_id: id}), do: not is_nil(id)

  @doc """
  Combine first_name and last_name into one name.
  """
  def name(user) do
    [
      user.first_name,
      user.last_name
    ]
    |> Enum.map_join(" ", fn x ->
      "#{x}"
      |> String.trim()
      |> String.capitalize()
    end)
    |> String.trim()
  end

  def first_name(user) do
    "#{user.first_name}"
    |> String.trim()
    |> String.capitalize()
  end

  def timezone(%{timezone: tz}) when not is_nil(tz), do: tz

  def timezone(%{timezone_device: tz}) when not is_nil(tz), do: tz

  def timezone(%{timezone_argyle: tz}) when not is_nil(tz), do: tz

  def timezone(_), do: "Etc/UTC"

  @doc """
  Get the beginning and ending times in UTC for a given working day by adjusting
  for the user's timezone.

  Metrics for a day start at 4am, and end at 4am the following day in the user's
  timezone.

  NOTE: Working days are not always 24 hours long. DST can alter their length.
  """
  def working_day_bounds(date, user) do
    tz = timezone(user)

    DateTimeUtil.working_day_bounds(date, tz)
  end

  def get_next_working_day_boundary(%DateTime{time_zone: "Etc/UTC"} = datetime, user) do
    tz = timezone(user)

    # WARN: this can fail on certain ambigious times due to DST and we don't
    # have a way to handle that yet

    # get the working day boundary of the current day
    boundary =
      datetime
      |> DateTime.to_date()
      |> DateTime.new!(@working_day_end_time, tz)
      |> DateTime.shift_zone!("Etc/UTC")

    if DateTime.compare(datetime, boundary) == :lt do
      # datetime is before to the boundary, so it's good
      boundary
    else
      # the given datetime occurs after or at the same time as the boundary we
      # computed, skip ahead a day to the next boundary
      datetime
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(@working_day_end_time, tz)
      |> DateTime.shift_zone!("Etc/UTC")
    end
  end

  @doc """
  Take a datetime in UTC and covert it to the corresponding working day for a
  given user.

  This only supports UTC DateTime objects because timezones that use DST have
  ambigous times that cannot be converted.
  """
  def datetime_to_working_day(%DateTime{time_zone: "Etc/UTC"} = datetime, user) do
    DateTimeUtil.datetime_to_working_day(datetime, timezone(user))
  end

  @doc false
  def changeset(user, attrs) do
    changeset =
      user
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_length(:email, min: 1, max: 100)
      |> validate_format(:email, ~r/@/)
      |> validate_inclusion(:vehicle_type, @valid_vehicle_types)
      |> validate_inclusion(:is_beta, @valid_app_channels)
      |> validate_inclusion(:role, @valid_roles)
      |> validate_timezone(:timezone)
      |> validate_timezone(:timezone_argyle)
      |> validate_timezone(:timezone_device)
      |> unique_constraint(:email, name: :users_email_index)
      |> cast_metro_area()

    changeset =
      if get_change(changeset, :password) do
        changeset
        |> validate_length(:password, min: 8, max: 100)
        |> put_password_hash()
      else
        changeset
      end

    changeset =
      if get_change(changeset, :opted_out_of_data_sale_at) do
        changeset
        |> put_opted_out_of_data_sale_at()
      else
        changeset
      end

    changeset =
      if get_change(changeset, :opted_out_of_sensitive_data_use_at) do
        changeset
        |> put_opted_out_of_sensitive_data_use_at()
      else
        changeset
      end

    if get_change(changeset, :referral_code) do
      try_put_referral_source_id(changeset)
    else
      changeset
    end
  end

  def admin_changeset(user, attrs) do
    user = cast(user, attrs, [:role])

    changeset(user, attrs)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 100)
    |> put_password_hash()
  end

  def try_put_referral_source_id(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{referral_code: nil}} ->
        put_change(changeset, :referral_source_id, nil)
        |> put_change(:referral_code, nil)

      %Ecto.Changeset{valid?: true, changes: %{referral_code: ref_code}} ->
        case DriversSeatCoop.ReferralSources.get_referral_source(ref_code) do
          nil ->
            add_error(changeset, :referral_code, "referral code not found")

          %{is_active: false} ->
            add_error(changeset, :referral_code, "referral code is no longer active")

          %{is_active: true} = referral_source ->
            put_change(changeset, :referral_source_id, referral_source.id)
            |> put_change(:referral_code, nil)
        end
    end
  end

  def reset_password_changeset(user) do
    token =
      :crypto.strong_rand_bytes(64)
      |> Base.url_encode64()
      |> binary_part(0, 64)

    # expires in one day
    expire_time =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(60 * 60 * 24, :second)

    user
    |> cast(%{reset_password_token: token, reset_password_token_expires_at: expire_time}, [
      :reset_password_token,
      :reset_password_token_expires_at
    ])
    |> validate_required([:reset_password_token, :reset_password_token_expires_at])
  end

  def change_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 100)
    |> put_password_hash()
    |> put_change(:reset_password_token, nil)
    |> put_change(:reset_password_token_expires_at, nil)
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Argon2.hash_pwd_salt(pass))
        |> put_change(:password, nil)

      _ ->
        changeset
    end
  end

  def put_opted_out_of_data_sale_at(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{opted_out_of_data_sale_at: opt_out}} ->
        cond do
          is_nil(changeset.data.opted_out_of_data_sale_at) and is_nil(opt_out) ->
            put_change(changeset, :opted_out_of_data_sale_at, NaiveDateTime.utc_now())

          is_nil(opt_out) ->
            put_change(changeset, :opted_out_of_data_sale_at, nil)

          true ->
            changeset
        end

      _ ->
        changeset
    end
  end

  def put_opted_out_of_sensitive_data_use_at(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{opted_out_of_sensitive_data_use_at: opt_out}} ->
        cond do
          is_nil(changeset.data.opted_out_of_sensitive_data_use_at) and is_nil(opt_out) ->
            put_change(changeset, :opted_out_of_sensitive_data_use_at, NaiveDateTime.utc_now())

          is_nil(opt_out) ->
            put_change(changeset, :opted_out_of_sensitive_data_use_at, nil)

          true ->
            changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_timezone(changeset, field) do
    timezone = get_field(changeset, field)

    if is_nil(timezone) do
      changeset
    else
      # try to get the current time with the given timezone
      case DateTime.now(get_field(changeset, field)) do
        {:ok, %DateTime{}} ->
          changeset

        _ ->
          add_error(changeset, field, "invalid timezone")
      end
    end
  end

  def is_prod_user(%DriversSeatCoop.Accounts.User{} = user) do
    email = String.downcase(user.email)

    String.contains?(email, "driversseat") or String.contains?(email, "driverseat") or
      String.contains?(email, "rokkin")
  end

  def cast_metro_area(changeset) do
    has_change_postal_code = get_change(changeset, :postal_code, @not_avail) != @not_avail

    has_change_postal_code_argyle =
      get_change(changeset, :postal_code_argyle, @not_avail) != @not_avail

    has_change_metro_area_id = get_change(changeset, :metro_area_id, @not_avail) != @not_avail

    has_change =
      has_change_postal_code or has_change_postal_code_argyle or has_change_metro_area_id

    postal_code = get_field(changeset, :postal_code)
    postal_code_argyle = get_field(changeset, :postal_code_argyle)
    metro_area_id = get_field(changeset, :metro_area_id)

    metro_area_id =
      if has_change or is_nil(metro_area_id),
        do:
          Map.get(
            Regions.get_metro_area_by_postal_code([postal_code, postal_code_argyle]) || %{},
            :id
          ),
        else: metro_area_id

    cast(changeset, %{metro_area_id: metro_area_id}, [:metro_area_id])
  end
end
