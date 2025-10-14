defmodule DriversSeatCoop.Mixpanel do
  alias DriversSeatCoop.Accounts.User

  @url "https://api.mixpanel.com"
  @page_size 500
  @timeout_ms 30_000

  @profile_fields_to_remove [
    "$email",
    "$initial_referrer",
    "$initial_referring_domain",
    "$name",
    "Car Ownership",
    "Country",
    "Email",
    "Engine Type",
    "Ethnicity",
    "Focus Group",
    "Gender",
    "Is Beta",
    "Opted Out of Data Sale",
    "Opted Out of Push Notifications",
    "Profile ID",
    "Referral Code",
    "Services",
    "Timezone",
    "Vehicle Make",
    "Vehicle Model",
    "Vehicle Type",
    "Vehicle Year",
    "Zip Code",
    "_optOutDataSaleAt",
    "_optOutSensitiveDataUseAt",
    "agreed_to_current_terms",
    "app_version",
    "average_gross_pay",
    "average_net_pay",
    "bubble_user_id",
    "car_ownership",
    "contact_permission",
    "country",
    "created_at",
    "creation date",
    "currently_on_shift",
    "device_platform",
    "email",
    "enabled_features",
    "engine_type",
    "enrolled_research_at",
    "environment",
    "ethnicity",
    "first_name",
    "focus_group",
    "gender",
    "has_referral_source",
    "id",
    "is_beta",
    "is_demo_account",
    "language_code",
    "last_name",
    "metro_area_id",
    "opted_out_of_data_sale_at",
    "opted_out_of_push_notifications",
    "phone_number",
    "population/dsc_feedback_interview_invite",
    "population/exp_activities_notif",
    "population/exp_onboarding_surveys",
    "population/exp_onboarding_welcome",
    "population/metro_area",
    "population/recommendations",
    "population/test",
    "postal_code",
    "remind_shift_end",
    "remind_shift_start",
    "service_names",
    "source",
    "timezone",
    "timezone_device",
    "unenrolled_research_at",
    "vehicle_make",
    "vehicle_model",
    "vehicle_type",
    "vehicle_year"
  ]

  def track_event(%User{} = user, event, additional_data) do
    if has_config?() do
      url = "#{@url}/track"

      properties =
        (additional_data || %{})
        |> Map.merge(%{
          token: api_token(),
          time: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          distinct_id: user.id,
          "$insert_id": Ecto.UUID.generate()
        })

      body = [
        %{
          event: event,
          properties: properties
        }
      ]

      post(url, body)
    else
      {:ok, :not_configured}
    end
  end

  def set_population(%User{} = user, population_type_code, populations) do
    populations = List.wrap(populations)

    if has_config?() do
      url = "#{@url}/engage#profile-set"

      body = [
        %{
          "$token": api_token(),
          "$distinct_id": user.id,
          "$set": %{
            "population/#{population_type_code}": populations
          }
        }
      ]

      post(url, body)
    else
      {:ok, :not_configured}
    end
  end

  @doc """
  Deidentify a user instead of deleting them so that our usage stats remain the same.
  The "Prod" cohort uses profile fields to include/exclude a user.  Keeping the profile
  but deidentifying them allows this to work.
  """
  def deidentify_user(distinct_id) do
    if has_config?() do
      url = "#{@url}/engage#profile-unset"

      body = [
        %{
          "$token": api_token(),
          "$distinct_id": distinct_id,
          "$unset": @profile_fields_to_remove
        }
      ]

      post(url, body)
    else
      {:ok, :not_configured}
    end
  end

  def delete_user(distinct_id) do
    if has_config?() do
      url = "#{@url}/engage#profile-delete"

      body = [
        %{
          "$token": api_token(),
          "$distinct_id": distinct_id,
          "$delete": nil,
          "$ignore_alias": false
        }
      ]

      post(url, body)
    else
      {:ok, :not_configured}
    end
  end

  def query_users, do: %{}

  def query_users_with_output_field(qry, field_or_fields) do
    field_or_fields =
      List.wrap(field_or_fields)
      |> Enum.map(fn f -> "#{f}" end)

    field_or_fields = Map.get(qry, :output_properties, []) ++ field_or_fields

    field_or_fields = Enum.uniq(field_or_fields)

    Map.put(qry, :output_properties, field_or_fields)
  end

  def query_users_with_page_size(qry, page_size) when is_integer(page_size) and page_size > 0 do
    Map.put(qry, :page_size, page_size)
  end

  def query_users_filter(qry, field, value_or_values) do
    filter =
      List.wrap(value_or_values)
      |> Enum.map_join(" OR ", fn v ->
        ~s(properties["#{field}"] == "#{v}")
      end)

    filter = "(#{filter})"

    filter_or_filters =
      Map.get(qry, :where, [])
      |> List.insert_at(-1, filter)

    Map.put(qry, :where, filter_or_filters)
  end

  def query_users_exec(qry) do
    where = Map.get(qry, :where)

    qry =
      if is_nil(where) do
        qry
      else
        where = Enum.join(where, " and ")
        Map.put(qry, :where, where)
      end

    case x = query_users_impl(qry) do
      {:ok, :not_configured} ->
        {:ok, :not_configured}

      {:ok, mixpanel_users} ->
        {:ok, :results,
         Enum.map(mixpanel_users, fn mxu ->
           Map.get(mxu, "$properties", %{})
           |> Map.put_new("$distinct_id", Map.get(mxu, "$distinct_id"))
         end)}

      _ ->
        x
    end
  end

  defp query_users_impl(qry) do
    if has_config?() do
      qry = Map.put_new(qry, :page_size, @page_size)

      url = "https://mixpanel.com/api/2.0/engage?project_id=#{project_id()}"

      with {:ok, result} <- post_using_service_account(url, qry) do
        rows = Map.get(result, "results")
        page = Map.get(result, "page")
        session_id = Map.get(result, "session_id")

        if Enum.count(rows) < @page_size do
          {:ok, rows}
        else
          qry =
            qry
            |> Map.put(:page, page + 1)
            |> Map.put(:session_id, session_id)

          qry_result = query_users_impl(qry)

          case qry_result do
            {:ok, other_rows} ->
              {:ok, rows ++ other_rows}

            _ ->
              qry_result
          end
        end
      end
    else
      {:ok, :not_configured}
    end
  end

  defp post(url, body) do
    if has_config?() do
      headers = [
        {"content-type", "application/json"},
        {"accept", "text/plain"}
      ]

      with {:ok, body} <- Jason.encode(body),
           {:ok, 200, _, client} <- :hackney.request(:post, url, headers, body),
           {:ok, response} <- :hackney.body(client),
           {:ok, _} <- Jason.decode(response) do
        {:ok, :updated}
      else
        {:ok, 400, _, _} -> {:error, :invalid_app_id_or_app_key}
        {:error, result} -> {:error, :not_tracked, result}
        result -> {:error, :not_updated, result}
      end
    else
      {:ok, :not_configured}
    end
  end

  defp has_config? do
    config = get_config()

    cond do
      is_nil(config) -> false
      is_nil(Keyword.get(config, :project_token)) -> false
      is_nil(Keyword.get(config, :project_id)) -> false
      is_nil(Keyword.get(config, :service_account_id)) -> false
      is_nil(Keyword.get(config, :service_account_secret)) -> false
      true -> true
    end
  end

  defp get_config do
    Application.get_env(:dsc, DriversSeatCoop.Mixpanel)
  end

  defp api_token, do: get_config()[:project_token]
  defp project_id, do: get_config()[:project_id]
  defp service_account_id, do: get_config()[:service_account_id]
  defp service_account_secret, do: get_config()[:service_account_secret]

  defp post_using_service_account(url, body) do
    if has_config?() do
      base64 = Base.encode64("#{service_account_id()}:#{service_account_secret()}")

      headers = [
        {"content-type", "application/json"},
        {"accept", "application/json"},
        {"authorization", "Basic #{base64}"}
      ]

      with {:ok, body} <- Jason.encode(body),
           {:ok, response} <- HTTPoison.post(url, body, headers, recv_timeout: @timeout_ms) do
        case {response.status_code, response.body} do
          {200, body} -> {:ok, Jason.decode!(body)}
          {status, body} -> {:error, status, body}
        end
      end
    else
      {:ok, :not_configured}
    end
  end
end
