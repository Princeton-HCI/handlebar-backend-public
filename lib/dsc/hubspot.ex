defmodule DriversSeatCoop.HubSpot do
  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User

  require Logger

  @external_resource "priv/data/bad_emails.txt"
  @bad_emails File.read!(@external_resource) |> String.split("\n") |> MapSet.new()
  @contacts_api_url "https://api.hubapi.com/contacts/v1"
  @page_size 100
  @timeout_ms 30_000

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

  def query_users_exec(qry \\ %{}) do
    if has_config?() do
      result = get_contacts_impl(qry)

      case result do
        {:ok, :not_configured} ->
          result

        {:ok, :results, hubspot_users} ->
          results =
            Enum.map(hubspot_users, fn hbu ->
              props = Map.get(hbu, "properties") || %{}

              Enum.reduce(props, %{}, fn {k, v}, model ->
                if is_map(v) and Map.has_key?(v, "value"),
                  do: Map.put(model, k, Map.get(v, "value")),
                  else: Map.put(model, k, v)
              end)
              |> Map.merge(Map.take(hbu, ["vid", "merged_vids"]))
            end)

          {:ok, :results, results}

        _ ->
          result
      end
    else
      {:ok, :not_configured}
    end
  end

  def get_contacts_impl(qry, offset \\ nil) do
    page_size = Map.get(qry, :page_size) || @page_size

    properties = List.wrap(Map.get(qry, :output_properties))

    url = "#{@contacts_api_url}/lists/all/contacts/all?count=#{page_size}"

    url =
      if Enum.any?(properties),
        do: Enum.reduce(properties, url, fn p, u -> "#{u}&property=#{p}" end),
        else: url

    url =
      if is_nil(offset),
        do: url,
        else: "#{url}&vidOffset=#{offset}"

    case request(:get, url) do
      # all we need is the vid
      {:ok, body} ->
        rows = get_in(body, ["contacts"])
        has_more = get_in(body, ["has-more"])
        vid_offset = get_in(body, ["vid-offset"])

        if has_more == true and not is_nil(vid_offset) do
          {:ok, :results, other_rows} = get_contacts_impl(qry, vid_offset)
          {:ok, :results, rows ++ other_rows}
        else
          {:ok, :results, rows || []}
        end

      {:error, e} ->
        {:error, e}
    end
  end

  def create_or_update_contact(user) do
    case get_contact_by_email(user.email) do
      {:ok, contact} ->
        update_contact_by_vid(contact.vid, user)

      {:error, :contact_missing} ->
        create_contact(user)
    end
  end

  def get_contact_by_email(email) when is_binary(email) do
    url = "#{@contacts_api_url}/contact/email/#{email}/profile"

    case request(:get, url) do
      # all we need is the vid
      {:ok, body} -> {:ok, %{vid: Map.fetch!(body, "vid")}}
      {:error, e} -> {:error, e}
    end
  end

  def create_contact(%User{} = user) do
    body = %{
      properties: user_properties(user)
    }

    url = "#{@contacts_api_url}/contact"
    json_request(:post, url, body)
  end

  def update_contact_by_vid(vid, %User{} = user) do
    body = %{
      properties: user_properties(user)
    }

    url = "#{@contacts_api_url}/contact/vid/#{vid}/profile"
    json_request(:post, url, body)
  end

  def delete_contact(vid) do
    url = "#{@contacts_api_url}/contact/vid/#{vid}"

    request(:delete, url)
  end

  def is_bad_email?(nil), do: true

  def is_bad_email?(email) do
    not String.match?(email, ~r/@.+\./) || MapSet.member?(@bad_emails, email)
  end

  def enabled?, do: is_binary(api_key())

  def get_config do
    Application.get_env(:dsc, DriversSeatCoop.HubSpot)
  end

  defp has_config? do
    config = get_config()

    cond do
      is_nil(config) -> false
      is_nil(Keyword.get(config, :api_key)) -> false
      true -> true
    end
  end

  defp api_key, do: get_config()[:api_key]

  defp hubspot_property(hubspot_name, value) when is_binary(hubspot_name) do
    %{property: hubspot_name, value: hubspot_value(value)}
  end

  defp hubspot_value(nil), do: nil

  defp hubspot_value(value) when is_list(value) do
    Enum.join(value, ";")
  end

  defp hubspot_value(%NaiveDateTime{} = value) do
    value
    |> NaiveDateTime.to_date()
    |> hubspot_value()
  end

  defp hubspot_value(%Date{} = value) do
    # Hubspot requires dates to be in millisecond Unix time and have 0 in
    # hours, minutes, seconds
    value
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  defp hubspot_value(value), do: value

  def user_properties(user) do
    last_session_datetime = Accounts.get_last_user_session_refresh(user.id)

    [
      hubspot_property("email", user.email),
      hubspot_property("phone", user.phone_number),
      hubspot_property("firstname", user.first_name),
      hubspot_property("lastname", user.last_name),
      hubspot_property("country", user.country),
      hubspot_property("zip", user.postal_code),
      hubspot_property("became_registered_user_date", user.inserted_at),
      hubspot_property("app_user_id", user.id),
      hubspot_property(
        "app_services_long_form_",
        user.service_names && Enum.join(user.service_names, ",")
      ),
      hubspot_property("app_device_platform", user.device_platform),
      hubspot_property("app_focus_group", user.focus_group),
      hubspot_property("type", "Driver"),
      hubspot_property("channel_source", "App Registration"),
      hubspot_property("last_app_use_date", last_session_datetime)
    ]
    |> Enum.filter(fn x ->
      not is_nil(x.value)
    end)
  end

  defp json_request(method, url, body) do
    body = Jason.encode!(body)
    header = [{"content-type", "application/json"}]
    request(method, url, body, header)
  end

  defp request(method, url, body \\ [], header \\ []) do
    header = header ++ [{"authorization", "Bearer #{api_key()}"}]

    {:ok, response} = HTTPoison.request(method, url, body, header, recv_timeout: @timeout_ms)

    case {response.status_code, response.body} do
      {204, _} -> {:ok, nil}
      {200, nil} -> {:ok, nil}
      {200, body} -> {:ok, Jason.decode!(body)}
      {409, _body} -> {:error, :contact_exists}
      {404, _body} -> {:error, :contact_missing}
      {400, body} -> {:error, parse_hubspot_error(body)}
      {_, body} -> {:error, body}
    end
  end

  defp parse_hubspot_error(body) do
    with {:ok, error} <- Jason.decode(body),
         %{"validationResults" => validation_results} <- error,
         [%{"error" => "INVALID_EMAIL"} | _] <- validation_results do
      :invalid_email_address
    else
      # couldn't extract an error, return the whole body
      _ -> body
    end
  end
end
