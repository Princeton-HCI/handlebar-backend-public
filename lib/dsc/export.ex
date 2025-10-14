defmodule DriversSeatCoop.Export do
  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.CSV
  alias DriversSeatCoop.Earnings
  alias DriversSeatCoop.Earnings.Oban.ExportUserEarningsQuery
  alias DriversSeatCoop.Repo

  require Logger

  def upload_csv_stream(content, filename, compress)
      when is_boolean(compress) do
    # File upload functionality removed - B2 integration deleted
    {:ok, :upload_disabled}
  end

  def round_number(nil), do: nil

  def round_number(0), do: "0.00"

  def round_number(%Decimal{} = number) do
    number
    |> Decimal.round(2)
  end

  def round_number(number) do
    number
    |> Decimal.from_float()
    |> Decimal.round(2)
  end

  defmodule UserRequest do
    defmodule Earnings do
      alias DriversSeatCoop.Earnings
      alias DriversSeatCoop.Export

      @decimal_0 Decimal.new(0)
      @seconds_in_hour 60 * 60

      @export_meas_columns [
        :pay,
        :tip,
        :promotion,
        :jobs,
        :miles_engaged,
        :miles_engaged_irs_deduction_estimate,
        :work_hours_engaged
      ]

      @export_meas_columns_non_work [
        :miles_not_engaged,
        :miles_not_engaged_irs_deduction_estimate,
        :work_hours_not_engaged
      ]

      @export_detail_columns [
        :type,
        :id,
        :job_hours,
        :work_day,
        :employer,
        :start_date,
        :start_time,
        :end_date,
        :end_time
      ]

      def export_earnings_for_user_query(user_id, query) do
        user = Accounts.get_user!(user_id)

        uuid = Ecto.UUID.generate()
        path = "export_requests/#{user_id}/earnings_#{uuid}.csv"

        {models, columns} =
          get_export_earnings_data(
            user,
            Date.from_iso8601!(Map.get(query, "date_start")),
            Date.from_iso8601!(Map.get(query, "date_end")),
            Map.get(query, "include_non_p3_time", false),
            Map.get(query, "groupings")
          )

        data =
          CSV.build_csv_stream(models, columns)
          |> Enum.to_list()

        Export.upload_csv_stream(data, path, false)
      end

      def get_export_earnings_data(
            user,
            work_date_start,
            work_date_end,
            include_non_work_time,
            groupings
          ) do
        groupings = List.wrap(groupings)

        if Enum.empty?(groupings) do
          get_export_earnings_details(user, work_date_start, work_date_end, include_non_work_time)
        else
          get_export_earnings_summary(
            user,
            work_date_start,
            work_date_end,
            include_non_work_time,
            groupings
          )
        end
      end

      defp get_export_earnings_details(
             user,
             work_date_start,
             work_date_end,
             include_non_work_time
           ) do
        timezone = User.timezone(user)

        # identify the columns and create a blank template with all of the properties
        columns = @export_detail_columns ++ @export_meas_columns

        columns =
          if include_non_work_time, do: columns ++ @export_meas_columns_non_work, else: columns

        template = Enum.reduce(columns, %{}, fn c, m -> Map.put(m, c, nil) end)

        # get the timespans->allocations->activities
        timespans =
          Earnings.get_timespan_details(user.id, "user_facing", work_date_start, work_date_end)

        records =
          get_export_earnings_details_time_and_mileage(timezone, timespans) ++
            get_export_earnings_details_jobs(timezone, timespans) ++
            get_export_earnings_details_other_earnings(user.id, work_date_start, work_date_end)

        records =
          records
          |> Enum.map(fn x -> Map.merge(template, Map.take(x, columns)) end)
          |> Enum.sort_by(fn x -> x.work_day end, Date)

        {records, columns}
      end

      # credo:disable-for-next-line
      defp get_export_earnings_details_time_and_mileage(timezone, timespans) do
        Enum.map(timespans, fn ts ->
          start_time = DateTime.shift_zone!(ts.start_time, timezone)
          end_time = DateTime.shift_zone!(ts.end_time, timezone)

          %{
            type: "summary",
            id: ts.id,
            work_day: ts.work_date,
            start_date: DateTime.to_date(start_time),
            start_time: DateTime.to_time(start_time),
            end_date: DateTime.to_date(end_time),
            end_time: DateTime.to_time(end_time),
            miles_engaged:
              (ts.selected_miles_engaged || @decimal_0)
              |> Decimal.to_float(),
            miles_engaged_irs_deduction_estimate:
              (ts.selected_miles_deduction_cents_engaged || 0) / 100,
            work_hours_engaged:
              ((ts.duration_seconds_engaged || 0) / @seconds_in_hour)
              |> Float.round(3),
            miles_not_engaged:
              Decimal.sub(
                ts.selected_miles || @decimal_0,
                ts.selected_miles_engaged || @decimal_0
              )
              |> Decimal.to_float(),
            miles_not_engaged_irs_deduction_estimate:
              ((ts.selected_miles_deduction_cents || 0) -
                 (ts.selected_miles_deduction_cents_engaged || 0)) / 100,
            work_hours_not_engaged:
              (((ts.duration_seconds || 0) - (ts.duration_seconds_engaged || 0)) /
                 @seconds_in_hour)
              |> Float.round(3)
          }
        end)
      end

      defp get_export_earnings_details_jobs(timezone, timespans) do
        Enum.flat_map(timespans, fn ts ->
          ts.allocations
          |> Enum.filter(fn alloc -> not is_nil(alloc.activity_id) end)
          |> Enum.map(fn alloc ->
            start_time = DateTime.shift_zone!(alloc.start_time, timezone)
            end_time = DateTime.shift_zone!(alloc.end_time, timezone)

            %{
              type: alloc.activity.earning_type,
              id: alloc.activity_id,
              work_day: ts.work_date,
              employer: alloc.activity.employer,
              start_date: DateTime.to_date(start_time),
              start_time: DateTime.to_time(start_time),
              end_date: DateTime.to_date(end_time),
              end_time: DateTime.to_time(end_time),
              pay:
                alloc.activity_coverage_percent
                |> Decimal.mult(alloc.activity.earnings_pay_cents || 0)
                |> Decimal.div(100)
                |> Decimal.round(2)
                |> Decimal.to_float(),
              tip:
                alloc.activity_coverage_percent
                |> Decimal.mult(alloc.activity.earnings_tip_cents || 0)
                |> Decimal.div(100)
                |> Decimal.round(2)
                |> Decimal.to_float(),
              promotion:
                alloc.activity_coverage_percent
                |> Decimal.mult(alloc.activity.earnings_bonus_cents || 0)
                |> Decimal.div(100)
                |> Decimal.round(2)
                |> Decimal.to_float(),
              jobs:
                alloc.activity_coverage_percent
                |> Decimal.mult(alloc.activity.tasks_total || 1)
                |> Decimal.round(2)
                |> Decimal.to_float(),
              job_hours:
                ((alloc.duration_seconds || 0) / @seconds_in_hour)
                |> Float.round(3)
            }
          end)
        end)
      end

      defp get_export_earnings_details_other_earnings(user_id, work_date_start, work_date_end) do
        Earnings.get_other_earnings_query(user_id, work_date_start, work_date_end)
        |> Repo.all()
        |> Enum.map(fn activity ->
          %{
            type: activity.earning_type,
            id: activity.id,
            work_day: activity.working_day_start,
            employer: activity.employer,
            pay:
              ((activity.earnings_pay_cents || 0) / 100)
              |> Float.round(2),
            tip:
              ((activity.earnings_tip_cents || 0) / 100)
              |> Float.round(2),
            promotion:
              ((activity.earnings_bonus_cents || 0) / 100)
              |> Float.round(2)
          }
        end)
      end

      defp get_export_earnings_summary(
             user,
             work_date_start,
             work_date_end,
             include_non_work_time,
             groupings
           ) do
        other_groupings = Enum.filter(groupings, fn g -> g == "employer" end)

        time_grouping =
          groupings
          |> Enum.filter(fn g -> g != "employer" end)
          |> Enum.at(0)

        groupings =
          groupings
          |> Enum.map(fn g -> String.to_atom("#{g}") end)

        time_and_mileage =
          Earnings.get_overall_time_and_mileage_summary(
            user.id,
            "user_facing",
            work_date_start,
            work_date_end,
            time_grouping
          )

        job_earnings =
          Earnings.get_job_earnings_summary(
            user.id,
            "user_facing",
            work_date_start,
            work_date_end,
            time_grouping,
            other_groupings
          )

        other_earnings =
          Earnings.get_other_earnings_summary(
            user.id,
            work_date_start,
            work_date_end,
            time_grouping,
            other_groupings
          )

        summaries =
          get_export_earnings_summary_combine_earnings(
            groupings,
            time_and_mileage,
            job_earnings,
            other_earnings
          )

        get_export_earnings_summary_create_models(groupings, summaries, include_non_work_time)
      end

      defp get_export_earnings_summary_combine_earnings(
             groupings,
             time_and_mileage,
             job_earnings,
             other_earnings
           ) do
        # ensure that time and mileage records have keys for all grouping columns
        # by default, they will not have groupings for employers, etc.
        group_keys_template = Map.from_keys(groupings, nil)

        time_and_mileage =
          time_and_mileage
          |> Enum.map(fn x -> Map.merge(group_keys_template, x) end)

        # earnings data has some overlapping columns with time and mileage data
        # for exporting, we favor time and mileage values.  So, remove them from
        # earnings data
        earnings_keep_cols =
          [
            :job_count,
            :job_count_tasks,
            :job_earnings_bonus_cents,
            :job_earnings_pay_cents,
            :job_earnings_tip_cents,
            :other_earnings_bonus_cents,
            :other_earnings_pay_cents,
            :other_earnings_tip_cents
          ] ++ groupings

        earnings =
          (job_earnings ++ other_earnings)
          |> Enum.map(fn e -> Map.take(e, earnings_keep_cols) end)

        # Group the records by keys, then merge the grouped items array into a single map
        (time_and_mileage ++ earnings)
        |> Enum.group_by(fn item -> Map.take(item, groupings) end)
        |> Map.values()
        |> Enum.map(fn grp ->
          Enum.reduce(grp, %{}, fn i, x -> Map.merge(x, i) end)
        end)
      end

      # credo:disable-for-next-line
      defp get_export_earnings_summary_create_models(groupings, summaries, include_non_work_time) do
        columns = groupings ++ @export_meas_columns

        columns =
          if include_non_work_time, do: columns ++ @export_meas_columns_non_work, else: columns

        models =
          Enum.map(summaries, fn item ->
            item
            |> Map.merge(%{
              pay:
                (((Map.get(item, :job_earnings_pay_cents) || 0) +
                    (Map.get(item, :other_earnings_pay_cents) || 0)) / 100)
                |> Float.round(2),
              tip:
                (((Map.get(item, :job_earnings_tip_cents) || 0) +
                    (Map.get(item, :other_earnings_tip_cents) || 0)) / 100)
                |> Float.round(2),
              promotion:
                (((Map.get(item, :job_earnings_bonus_cents) || 0) +
                    (Map.get(item, :other_earnings_bonus_cents) || 0)) / 100)
                |> Float.round(2),
              jobs: Map.get(item, :job_count_tasks) || 0,
              miles_engaged:
                (Map.get(item, :selected_miles_engaged) || @decimal_0)
                |> Decimal.to_float()
                |> Float.round(2),
              miles_engaged_irs_deduction_estimate:
                ((Map.get(item, :selected_miles_deduction_cents_engaged) || 0) / 100)
                |> Float.round(2),
              work_hours_engaged:
                ((Map.get(item, :duration_seconds_engaged) || 0) / @seconds_in_hour)
                |> Float.round(2),
              miles_not_engaged:
                Decimal.sub(
                  Map.get(item, :selected_miles) || @decimal_0,
                  Map.get(item, :selected_miles_engaged) || @decimal_0
                )
                |> Decimal.to_float()
                |> Float.round(2),
              miles_not_engaged_irs_deduction_estimate:
                (((Map.get(item, :selected_miles_deduction_cents) || 0) -
                    (Map.get(item, :selected_miles_deduction_cents_engaged) || 0)) / 100)
                |> Float.round(2),
              work_hours_not_engaged:
                (((Map.get(item, :duration_seconds) || 0) -
                    (Map.get(item, :duration_seconds_engaged) || 0)) / @seconds_in_hour)
                |> Float.round(2)
            })
            |> Map.take(columns)
          end)

        {models, columns}
      end
    end

    def export_all(user_id) do
      DriversSeatCoop.Earnings.get_timespan_years(user_id)
      |> Enum.sort()
      |> Enum.each(fn year ->
        params = %{
          date_start: Date.new!(year, 1, 1),
          date_end: Date.new!(year, 12, 31),
          include_non_p3_time: true
        }

        ExportUserEarningsQuery.schedule_job(user_id, params)
      end)
    end
  end
end
