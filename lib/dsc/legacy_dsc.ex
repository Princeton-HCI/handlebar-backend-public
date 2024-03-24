defmodule DriversSeatCoop.LegacyDSC do
  @moduledoc """
  Provides functions to query data from the legacy Driver's Seat instance.
  """
  import Ecto.Query, warn: false
  alias DriversSeatCoop.CommunityInsights.AverageHourlyPayStatDSC
  alias DriversSeatCoop.Employers
  alias DriversSeatCoop.Regions
  alias DriversSeatCoop.Repo

  require Logger

  defp default_opts(options) do
    (options || Keyword.new())
    |> Keyword.put_new(:login, api_login())
    |> Keyword.put_new(:password, api_password())
    |> Keyword.put_new(:url, api_url())
  end

  def get_api_token(options \\ nil) do
    options = default_opts(options)

    login = Keyword.get(options, :login)
    password = Keyword.get(options, :password)
    url = Keyword.get(options, :url)

    url = "#{url}/api/sessions"

    post_data = %{
      session: %{
        email: login,
        password: password
      }
    }

    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    with {:ok, post_data} <- Jason.encode(post_data),
         {:ok, response} <- HTTPoison.post(url, post_data, headers) do
      case {response.status_code, response.headers} do
        {200, headers} ->
          headers = Map.new(headers)
          Map.get(headers, "Authorization") || Map.get(headers, "authorization")

        {status, _} ->
          {:error, status}
      end
    end
  end

  def query_dsc_community_insights_stats(metro_area_id, options \\ nil) do
    metro_area = Regions.get_metro_area_by_id(metro_area_id)
    options = default_opts(options)

    url = Keyword.get(options, :url)

    token = get_api_token(options)

    qry_params =
      %{
        metro_area_name: metro_area.name
      }
      |> URI.encode_query(:rfc3986)

    url = "#{url}/api/analytics/hourly_pay/export?#{qry_params}"

    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"authorization", token}
    ]

    with {:ok, response} <- HTTPoison.get(url, headers, recv_timeout: 30_000) do
      case {response.status_code, response.body} do
        {200, body} -> {:ok, Jason.decode!(body)}
        {status, body} -> {:error, status, body}
      end
    end
  end

  defp get_employer_service_class_xref(dsc_stats) do
    dsc_stats
    |> Enum.map(fn stat ->
      {
        Map.get(stat, "employer_name"),
        Map.get(stat, "service_class_name")
      }
    end)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn {emp_name, svc_class_name} = k, result ->
      svc_class_id = Map.get(Employers.get_or_create_service_class(svc_class_name), :id)
      emp_id = Map.get(Employers.get_or_create_employer(emp_name), :id)

      emp_svc_class_id =
        Map.get(Employers.get_or_create_employer_service_class(svc_class_id, emp_id), :id)

      Map.put(result, k, emp_svc_class_id)
    end)
  end

  def get_dsc_community_insights_stats(metro_area_id, options \\ nil) do
    # Get DSC Stats
    {:ok, dsc_stats} = query_dsc_community_insights_stats(metro_area_id, options)

    # Translate Employer Svc Classes and Append Metro Area ID
    emp_svc_class_xref = get_employer_service_class_xref(dsc_stats)

    dsc_stats
    |> Enum.map(fn stat ->
      employer_name = Map.get(stat, "employer_name")
      service_class_name = Map.get(stat, "service_class_name")
      employer_service_class_id = Map.get(emp_svc_class_xref, {employer_name, service_class_name})

      stat
      |> Map.put("employer_service_class_id", employer_service_class_id)
      |> Map.put("metro_area_id", metro_area_id)
    end)
  end

  @doc """
  Update community insights calcs for a metro area and week combo
  """
  def update_avg_hr_pay_stats_for_metro_area(
        metro_area_id,
        options \\ nil
      ) do
    calc_stats = get_dsc_community_insights_stats(metro_area_id, options)

    existing_stats =
      from(stat in AverageHourlyPayStatDSC,
        where: stat.metro_area_id == ^metro_area_id
      )
      |> Repo.all()

    to_be_removed =
      Enum.reduce(calc_stats, existing_stats, fn stat, remaining ->
        week_start_date = Date.from_iso8601!(Map.get(stat, "week_start_date"))
        employer_service_class_id = Map.get(stat, "employer_service_class_id")
        day_of_week = Map.get(stat, "day_of_week")
        hour_local = Time.from_iso8601!(Map.get(stat, "hour_local"))

        match =
          Enum.find(remaining, fn x ->
            x.week_start_date == week_start_date and
              x.employer_service_class_id == employer_service_class_id and
              x.day_of_week == day_of_week and
              x.hour_local == hour_local
          end)

        remaining =
          if is_nil(match),
            do: remaining,
            else: Enum.reject(remaining, fn x -> x.id == match.id end)

        changeset = AverageHourlyPayStatDSC.changeset(match || %AverageHourlyPayStatDSC{}, stat)

        Repo.insert_or_update!(
          changeset,
          on_conflict: {:replace_all_except, [:inserted_at]},
          conflict_target: [
            :metro_area_id,
            :week_start_date,
            :employer_service_class_id,
            :day_of_week,
            :hour_local
          ]
        )

        remaining
      end)

    if Enum.any?(to_be_removed) do
      to_be_removed_ids =
        to_be_removed
        |> Enum.map(fn x -> x.id end)

      from(stat in AverageHourlyPayStatDSC,
        where: stat.id in ^to_be_removed_ids
      )
      |> Repo.delete_all(timeout: :infinity)
    end

    :ok
  end

  defp get_config do
    Application.get_env(:dsc, DriversSeatCoop.LegacyDSC)
  end

  defp api_login, do: get_config()[:login]
  defp api_password, do: get_config()[:password]
  defp api_url, do: get_config()[:url]
end
