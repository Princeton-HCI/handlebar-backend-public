defmodule DriversSeatCoop.Regions do
  import Ecto.Query, warn: false
  import Geo.PostGIS, warn: false
  import Ecto.Adapters.SQL, warn: false

  require Logger

  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Regions.County
  alias DriversSeatCoop.Regions.MetroArea
  alias DriversSeatCoop.Regions.PostalCode
  alias DriversSeatCoop.Regions.State
  alias DriversSeatCoop.Repo

  def get_state_by_id(nil = _id), do: nil

  def get_state_by_id(id) do
    query_states()
    |> where([st], st.id == ^id)
    |> Repo.one()
  end

  def query_states do
    non_geometry_fields = State.get_non_geometry_fields()

    from(state in State,
      select: ^non_geometry_fields
    )
  end

  def get_county_by_id(nil = _id), do: nil

  def get_county_by_id(id) do
    query_counties()
    |> where([st], st.id == ^id)
    |> Repo.one()
  end

  def query_counties do
    non_geometry_fields = County.get_non_geometry_fields()

    from(county in County,
      select: ^non_geometry_fields
    )
  end

  def get_postal_code(nil, _include_metro_area), do: nil

  def get_postal_code(postal_code, include_metro_area) do
    postal_code_fields = PostalCode.get_non_geometry_fields()

    qry =
      from(pc in PostalCode)
      |> where([pc], pc.postal_code == ^postal_code)
      |> limit(1)

    qry =
      if include_metro_area do
        postal_code_fields =
          postal_code_fields ++ [metro_area: MetroArea.get_non_geometry_fields()]

        qry
        |> preload(:metro_area)
        |> select(pc, ^postal_code_fields)
      else
        qry
        |> select(pc, ^postal_code_fields)
      end

    Repo.one(qry)
  end

  def query_postal_codes do
    non_geometry_fields = PostalCode.get_non_geometry_fields()

    from(pc in PostalCode,
      select: ^non_geometry_fields
    )
  end

  def get_metro_area_by_id(nil), do: nil

  def get_metro_area_by_id(id) do
    query_metro_areas()
    |> where([metro], metro.id == ^id)
    |> Repo.one()
  end

  def get_metro_area_id_for_point(nil = _point), do: nil

  def get_metro_area_id_for_point(%Geo.Point{} = point) do
    metro_area =
      query_metro_areas()
      |> query_metro_area_contains_point(point)
      |> limit(1)
      |> Repo.one()

    if is_nil(metro_area), do: nil, else: Map.get(metro_area, :id)
  end

  def get_county_for_point(nil = _point), do: nil

  def get_county_for_point(%Geo.Point{} = point) do
    query_counties()
    |> query_county_contains_point(point)
    |> limit(1)
    |> Repo.one()
  end

  def get_metro_areas do
    query_metro_areas()
    |> Repo.all()
  end

  def query_metro_areas do
    metro_fields = MetroArea.get_non_geometry_fields()

    from(metro in MetroArea,
      select: ^metro_fields
    )
  end

  def query_metro_areas_hourly_pay_stat_coverage_percent(qry, nil, nil), do: qry

  def query_metro_areas_hourly_pay_stat_coverage_percent(qry, nil, max),
    do: where(qry, [metro], metro.hourly_pay_stat_coverage_percent <= ^max)

  def query_metro_areas_hourly_pay_stat_coverage_percent(qry, min, nil),
    do: where(qry, [metro], metro.hourly_pay_stat_coverage_percent >= ^min)

  def query_metro_areas_hourly_pay_stat_coverage_percent(qry, min, max) do
    qry
    |> query_metro_areas_hourly_pay_stat_coverage_percent(min, nil)
    |> query_metro_areas_hourly_pay_stat_coverage_percent(nil, max)
  end

  def get_metro_area_for_user(%User{} = user),
    do: get_metro_area_by_postal_code([user.postal_code, user.postal_code_argyle])

  def get_metro_area_by_postal_code(postal_code_or_codes) do
    List.wrap(postal_code_or_codes)
    |> Enum.filter(fn pc -> not is_nil(pc) end)
    |> Enum.reduce(nil, fn pc, result ->
      if is_nil(result),
        do: Map.get(get_postal_code(pc, true) || %{}, :metro_area),
        else: result
    end)
  end

  def query_metro_area_contains_point(qry, %Geo.Point{} = point),
    do: where(qry, [m], st_within(^point, m.geometry))

  def query_county_contains_point(qry, %Geo.Point{} = point),
    do: where(qry, [m], st_within(^point, m.geometry))

  defmodule CensusTigerDB do
    alias DriversSeatCoop.Regions

    @tiger_url "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Census2020/MapServer"

    @state_layer_id 80
    @county_layer_id 82
    @micro_area_layer_id 78
    @metro_area_layer_id 76
    @postal_code_layer_id 84

    def update_states(offset \\ 0, batch_size \\ 10) do
      case query_tiger_db(@state_layer_id, offset, batch_size) do
        {:ok, result} ->
          Enum.each(result, fn state_obj ->
            state_attr = convert_tiger_db_state_to_attrs(state_obj)

            {:ok, _} =
              State.sync_changeset(%State{}, state_attr)
              |> Repo.insert(
                on_conflict: :replace_all,
                conflict_target: [:name]
              )
          end)

          if Enum.count(result) == batch_size do
            case update_states(offset + batch_size, batch_size) do
              :ok -> :ok
              _ = error_result -> error_result
            end
          else
            :ok
          end

        _ = problem ->
          problem
      end
    end

    defp convert_tiger_db_state_to_attrs(state_obj) do
      props = Map.get(state_obj, "properties")

      %{
        id: Map.get(props, "STATE"),
        name: Map.get(props, "NAME"),
        abbrv: Map.get(props, "STUSAB"),
        geometry:
          Map.get(state_obj, "geometry")
          |> add_srid_to_geo_json()
      }
    end

    def update_counties(offset \\ 0, batch_size \\ 50) do
      case query_tiger_db(@county_layer_id, offset, batch_size) do
        {:ok, result} ->
          Enum.each(result, fn county_obj ->
            county_attr = convert_tiger_db_county_to_attrs(county_obj)

            {:ok, _} =
              County.sync_changeset(%County{}, county_attr)
              |> Repo.insert(
                on_conflict: :replace_all,
                conflict_target: [:region_id_state, :name]
              )
          end)

          if Enum.count(result) == batch_size do
            case update_counties(offset + batch_size, batch_size) do
              :ok -> :ok
              error_result -> error_result
            end
          else
            :ok
          end

        _ = problem ->
          problem
      end
    end

    defp convert_tiger_db_county_to_attrs(county_obj) do
      props = Map.get(county_obj, "properties")

      %{
        id: Map.get(props, "OBJECTID"),
        region_id_state: Map.get(props, "STATE"),
        name: Map.get(props, "NAME"),
        geometry:
          Map.get(county_obj, "geometry")
          |> add_srid_to_geo_json()
      }
    end

    def update_metropolitan_areas(offset \\ 0, batch_size \\ 50),
      do: update_metro_or_micro_areas(@metro_area_layer_id, offset, batch_size)

    def update_micropolitan_areas(offset \\ 0, batch_size \\ 50),
      do: update_metro_or_micro_areas(@micro_area_layer_id, offset, batch_size)

    defp update_metro_or_micro_areas(layer_id, offset, batch_size) do
      case query_tiger_db(layer_id, offset, batch_size) do
        {:ok, result} ->
          Enum.each(result, fn metro_obj ->
            metro_attr = convert_tiger_db_metro_or_micro_to_attrs(metro_obj)

            {:ok, _} =
              MetroArea.sync_changeset(%MetroArea{}, metro_attr)
              |> Repo.insert(
                on_conflict: {:replace, [:name, :full_name, :geometry]},
                conflict_target: [:name]
              )
          end)

          if Enum.count(result) == batch_size do
            case update_metro_or_micro_areas(layer_id, offset + batch_size, batch_size) do
              :ok -> :ok
              _ = error_result -> error_result
            end
          else
            :ok
          end

        _ = problem ->
          problem
      end
    end

    defp convert_tiger_db_metro_or_micro_to_attrs(metro_obj) do
      props = Map.get(metro_obj, "properties")

      %{
        id: Map.get(props, "OBJECTID"),
        name: Map.get(props, "BASENAME"),
        full_name: Map.get(props, "NAME"),
        geometry:
          Map.get(metro_obj, "geometry")
          |> add_srid_to_geo_json()
      }
    end

    def update_postal_codes(offset \\ 0, batch_size \\ 200) do
      case query_tiger_db(@postal_code_layer_id, offset, batch_size) do
        {:ok, result} ->
          Enum.each(result, fn postal_code_obj ->
            postal_code_attr = convert_tiger_db_postal_code_to_attrs(postal_code_obj)

            {:ok, _} =
              PostalCode.sync_changeset(%PostalCode{}, postal_code_attr)
              |> Repo.insert(
                on_conflict: :replace_all,
                conflict_target: [:postal_code]
              )
          end)

          if Enum.count(result) == batch_size do
            case update_postal_codes(offset + batch_size, batch_size) do
              :ok -> :ok
              _ = error_result -> error_result
            end
          else
            :ok
          end

        _ = problem ->
          problem
      end
    end

    defp convert_tiger_db_postal_code_to_attrs(postal_code_obj) do
      props = Map.get(postal_code_obj, "properties")

      {center_lat, _} = Float.parse(Map.get(props, "INTPTLAT"))
      {center_lon, _} = Float.parse(Map.get(props, "INTPTLON"))

      center_point = %Geo.Point{coordinates: {center_lon, center_lat}, srid: 4326}

      county = Regions.get_county_for_point(center_point) || %{}

      %{
        id: Map.get(props, "OBJECTID"),
        postal_code: Map.get(props, "BASENAME"),
        geometry:
          Map.get(postal_code_obj, "geometry")
          |> add_srid_to_geo_json(),
        region_id_metro_area: Regions.get_metro_area_id_for_point(center_point),
        region_id_county: Map.get(county, :id),
        region_id_state: Map.get(county, :region_id_state)
      }
    end

    defp add_srid_to_geo_json(geometry),
      do:
        Geo.JSON.decode!(geometry)
        |> Map.put(:srid, 4326)

    defp query_tiger_db(layer_id, offset, batch_size) do
      qry_param = %{
        f: "geojson",
        outSR: 4326,
        geometryPrecision: 6,
        outFields: "*",
        where: "1=1",
        resultOffset: offset,
        resultRecordCount: batch_size,
        orderByFields: "OBJECTID"
      }

      qry_param = URI.encode_query(qry_param, :rfc3986)

      url = "#{@tiger_url}/#{layer_id}/query?#{qry_param}"

      Logger.info("Querying: #{url}")

      case http(:get, url) do
        {:ok, result} ->
          features = Map.get(result, "features")

          if is_nil(features),
            do: {:error, :no_features},
            else: {:ok, features}

        _ = problem ->
          problem
      end
    end

    defp http(method, url, body \\ [], header \\ []) do
      {:ok, response} = HTTPoison.request(method, url, body, header, recv_timeout: :infinity)

      case {response.status_code, response.body} do
        {204, _} ->
          {:ok, nil}

        {200, nil} ->
          {:ok, nil}

        {200, body} ->
          body = Jason.decode!(body)
          error = Map.get(body, "error")

          if is_nil(error) do
            {:ok, body}
          else
            {:error, error}
          end

        {_, body} ->
          {:error, body}
      end
    end
  end
end
