defmodule DriversSeatCoop.OneSignal do
  defmodule MessageTemplateParams do
    @enforce_keys [:include_external_user_ids, :template_id]
    defstruct [
      :include_external_user_ids,
      :additional_data,
      :template_id,
      :title
    ]
  end

  defmodule NonTemplateMessageParams do
    @enforce_keys [:include_external_user_ids, :title, :body]
    defstruct [
      :include_external_user_ids,
      :additional_data,
      :title,
      :body
    ]
  end

  require Logger

  alias DriversSeatCoop.Accounts
  alias DriversSeatCoop.Accounts.User
  alias DriversSeatCoop.Mixpanel
  alias DriversSeatCoop.OneSignal.MessageTemplateParams
  alias DriversSeatCoop.OneSignal.NonTemplateMessageParams

  @url "https://onesignal.com/api/v1/notifications"

  def send_notification_app_update_available(%User{} = user, _version_id) do
    send_notification(user, :app_update_available, %MessageTemplateParams{
      template_id: "8d4ef2ae-000c-4d47-b010-a3dbcf0f63c0",
      include_external_user_ids: [user.id]
    })
  end

  def send_notification_goals_check_progress(%User{} = user) do
    send_notification(user, :cta_goals_check_progress, %MessageTemplateParams{
      template_id: "191a3678-d720-4077-a89f-f5715f866ae1",
      include_external_user_ids: [user.id]
    })
  end

  def send_notification_goals_link_accounts(%User{} = user) do
    send_notification(user, :cta_goals_link_accounts, %MessageTemplateParams{
      template_id: "0f4b8921-41e5-4ceb-8aa2-b63d8c4798e4",
      include_external_user_ids: [user.id]
    })
  end

  def send_notification_goals_set_goals(%User{} = user) do
    send_notification(user, :cta_goals_set_goals, %MessageTemplateParams{
      template_id: "aad6192e-a582-4dd6-b5ca-23176f97b3da",
      include_external_user_ids: [user.id]
    })
  end

  def send_notification_goal_performance_update(
        %User{} = user,
        frequency,
        window_date,
        performance_percent,
        goal_amount_cents,
        performance_amount_cents
      ) do
    frequency = String.to_atom("#{frequency}")

    frequency_text =
      case frequency do
        :day -> "daily"
        :week -> "weekly"
        :month -> "monthly"
      end

    percent =
      if is_float(performance_percent),
        do: performance_percent,
        else: Decimal.to_float(performance_percent)

    percent = percent * 100
    percent = Float.round(percent, 0)
    percent = trunc(percent)

    goal_amt =
      (goal_amount_cents / 100)
      |> Float.round(0)
      |> Number.Delimit.number_to_delimited(precision: 0)

    title =
      if percent < 60 do
        "You're on your way!"
      else
        "You're almost there!"
      end

    body =
      "You're #{percent}% of the way to your #{frequency_text} goal of $#{goal_amt}. Keep it up, you've got this!"

    send_notification(user, "goal_performance_update_#{frequency}", %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: title,
      body: body,
      additional_data: %{
        body: body,
        frequency: frequency,
        window_date: window_date,
        performance_percent: percent,
        performance_amount: Float.round(performance_amount_cents / 100, 2),
        goal_amount: Float.round(goal_amount_cents / 100, 2)
      }
    })
  end

  def send_notification_goal_celebration(
        %User{} = user,
        frequency,
        window_date,
        performance_percent,
        goal_amount_cents,
        performance_amount_cents
      ) do
    frequency = String.to_atom("#{frequency}")

    frequency_text =
      case frequency do
        :day -> "daily"
        :week -> "weekly"
        :month -> "monthly"
      end

    percent =
      if is_float(performance_percent),
        do: performance_percent,
        else: Decimal.to_float(performance_percent)

    percent = percent * 100
    percent = Float.round(percent, 0)
    percent = trunc(percent)

    goal_amt =
      (goal_amount_cents / 100)
      |> Float.round(0)
      |> Number.Delimit.number_to_delimited(precision: 0)

    window_text =
      case frequency do
        :day -> "for #{Timex.format!(window_date, "{WDfull}")}"
        :week -> "for the week of #{Timex.format!(window_date, "{M}/{D}")}"
        :month -> "for #{Timex.format!(window_date, "{Mfull}")}"
      end

    challenge_text =
      if percent < 125 do
        "Keep your streak running by hitting your goal next time!"
      else
        "Up your game by increasing your goal in the earnings tab!"
      end

    title = "You hit your #{frequency_text} goal!"

    body =
      "Nice work! You hit #{percent}% of your #{frequency_text} goal of $#{goal_amt} #{window_text}. #{challenge_text}"

    send_notification(user, "goal_celebration_#{frequency}", %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: title,
      body: body,
      additional_data: %{
        body: body,
        frequency: frequency,
        window_date: window_date,
        performance_percent: percent,
        performance_amount: Float.round(performance_amount_cents / 100, 2),
        goal_amount: Float.round(goal_amount_cents / 100, 2)
      }
    })
  end

  def send_notification_new_activities(%User{} = user, activities) do
    count_activities = Enum.count(activities)

    employers =
      activities
      |> Enum.filter(fn a -> not is_nil(a.employer) end)
      |> Enum.map(fn a -> a.employer end)
      |> Enum.uniq()
      |> Enum.map(fn e -> String.capitalize(e) end)
      |> Enum.uniq()

    employers_text =
      case Enum.count(employers) do
        0 ->
          ""

        1 ->
          " from #{Enum.at(employers, 0)}"

        _ ->
          employer_csv =
            employers
            |> List.delete_at(-1)
            |> Enum.join(", ")

          " from #{employer_csv} and #{Enum.at(employers, -1)}"
      end

    title =
      if count_activities > 1 do
        "You have #{Number.Delimit.number_to_delimited(count_activities, precision: 0)} new gig activities!"
      else
        "You have a new gig activity!"
      end

    body = "Open Driver's Seat to see your earnings#{employers_text}."

    send_notification(user, :new_activities, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: title,
      body: body,
      additional_data: %{
        count_activities: count_activities,
        employers: employers
      }
    })
  end

  def send_cta_welcome_to_insights(%User{} = user, count_users_with_jobs) do
    send_notification(user, :cta_earnings_insights, %MessageTemplateParams{
      template_id: "1cfe418a-0def-4741-80f0-55bb7fa1b4ad",
      include_external_user_ids: [user.id],
      title:
        "Join #{Number.Delimit.number_to_delimited(count_users_with_jobs, precision: 0)} others on Driver's Seat",
      additional_data: %{
        count_users_with_jobs: count_users_with_jobs
      }
    })
  end

  def send_cta_welcome_to_community_insights_no_metro(
        %User{} = user,
        count_users_with_community_insights
      ) do
    send_notification(user, :cta_community_insights, %MessageTemplateParams{
      template_id: "563d4848-e4e6-414d-8421-9ad0adce46f1",
      include_external_user_ids: [user.id],
      title:
        "#{Number.Delimit.number_to_delimited(count_users_with_community_insights, precision: 0)} workers share earning tips!",
      additional_data: %{
        count_users_with_community_insights: count_users_with_community_insights,
        metro_area: "NULL"
      }
    })
  end

  # Metro DOES HAVE enough data, it doesn't matter if the user registered their argyle
  def send_cta_welcome_to_community_insights_has_metro(
        %User{} = user,
        metro_area,
        true = _enough_data,
        has_activity_data
      ) do
    params = %MessageTemplateParams{
      template_id: "df87fc4f-69de-4cd9-b8bf-1e8f04659b1e",
      include_external_user_ids: [user.id],
      additional_data: %{
        metro_area: metro_area.name,
        count_workers_in_metro: metro_area.count_workers,
        metro_has_enough_data: true,
        user_has_activities: has_activity_data
      }
    }

    params =
      if metro_area.count_workers < 5 do
        params
      else
        Map.put(
          params,
          :title,
          "Learn from #{Number.Delimit.number_to_delimited(metro_area.count_workers, precision: 0)} workers nearby!"
        )
      end

    send_notification(user, :cta_community_insights, params)
  end

  # Metro DOES NOT have enough data and the user HAS NOT registered their argyle accounts
  def send_cta_welcome_to_community_insights_has_metro(
        %User{} = user,
        metro_area,
        false = _enough_data,
        false = _has_activity_data
      ) do
    params = %MessageTemplateParams{
      template_id: "65f81062-3db9-4dd7-8ced-0b9ffb7aec01",
      include_external_user_ids: [user.id],
      additional_data: %{
        metro_area: metro_area.name,
        count_workers: metro_area.count_workers,
        metro_has_enough_data: false,
        user_has_activities: false
      }
    }

    params =
      if metro_area.count_workers < 5 do
        params
      else
        Map.put(
          params,
          :title,
          "#{Number.Delimit.number_to_delimited(metro_area.count_workers, precision: 0)} workers nearby need you!"
        )
      end

    send_notification(user, :cta_community_insights, params)
  end

  # Metro does NOT have enough data and the user HAS registered their argyle accounts
  def send_cta_welcome_to_community_insights_has_metro(
        %User{} = _user,
        _metro_area,
        false = _enough_data,
        true = _has_activity_data
      ) do
    {:ok, :notification_not_required}
  end

  def send_shift_start_reminder(%User{} = user, shift_start_time_local) do
    if User.can_receive_start_shift_notification(user) do
      send_notification(user, :start_shift_reminder, %MessageTemplateParams{
        template_id: "70bfc862-0d8a-41b2-9ba5-ca70ee47ac75",
        include_external_user_ids: [user.id],
        additional_data: %{
          shift_start_time_local: shift_start_time_local
        }
      })
    else
      {:ok, :user_cannot_receive_notification}
    end
  end

  def send_shift_end_reminder(%User{} = user, shift_end_time_local) do
    if User.can_receive_end_shift_notification(user) do
      send_notification(user, :end_shift_reminder, %MessageTemplateParams{
        template_id: "489daa0d-1229-4f27-be02-cfbff8d87884",
        include_external_user_ids: [user.id],
        additional_data: %{
          shift_end_time_local: shift_end_time_local
        }
      })
    else
      {:ok, :user_cannot_receive_notification}
    end
  end

  def send_data_ready_notification(user_id) do
    user = Accounts.get_user!(user_id)

    if User.can_receive_notification(user) do
      send_notification(user, :argyle_activities_available, %MessageTemplateParams{
        template_id: "916e4ec9-89d5-4367-93ba-53130067afee",
        include_external_user_ids: [user.id]
      })
    else
      {:ok, :user_cannot_receive_notification}
    end
  end

  defp send_notification(%User{} = user, notification_type, %MessageTemplateParams{} = params) do
    include_external_user_ids =
      params.include_external_user_ids
      |> Enum.map(&to_string/1)

    body = %{
      template_id: params.template_id,
      include_external_user_ids: include_external_user_ids,
      channel_for_external_user_ids: "push"
    }

    # if there is a title, add it
    title = Map.get(params, :title)

    body =
      if is_nil(title) do
        body
      else
        Map.put(body, :headings, %{
          en: title
        })
      end

    send(user, notification_type, body, Map.get(params, :additional_data))
  end

  defp send_notification(%User{} = user, notification_type, %NonTemplateMessageParams{} = params) do
    include_external_user_ids =
      params.include_external_user_ids
      |> Enum.map(&to_string/1)

    body = %{
      headings: %{
        en: params.title
      },
      contents: %{
        en: params.body
      },
      include_external_user_ids: include_external_user_ids,
      channel_for_external_user_ids: "push"
    }

    send(user, notification_type, body, Map.get(params, :additional_data))
  end

  defp send(%User{} = user, notification_type, post_body, additional_data) do
    api_key = api_key()
    app_id = app_id()

    cond do
      is_nil(api_key) or is_nil(app_id) ->
        {:ok, :not_configured}

      not User.can_receive_notification(user) ->
        {:ok, :user_cannot_receive_notification}

      true ->
        headers = [
          {"Authorization", "Basic #{api_key}"},
          {"Content-Type", "application/json"}
        ]

        body = Map.put(post_body, :app_id, app_id)

        with {:ok, body} <- Jason.encode(body),
             {:ok, 200, _, client} <- :hackney.request(:post, @url, headers, body),
             {:ok, response} <- :hackney.body(client),
             {:ok, _} <- Jason.decode(response) do
          Mixpanel.track_event(
            user,
            "notification/#{notification_type}",
            additional_data
          )

          {:ok, :sent}
        else
          {:ok, 400, _, _} -> {:error, :invalid_app_id_or_app_key}
          {:error, result} -> {:error, :not_sent, result}
          result -> {:error, :not_sent, result}
        end
    end
  end

  defp api_key do
    Application.get_env(:dsc, :one_signal_api_key)
  end

  defp app_id do
    Application.get_env(:dsc, :one_signal_app_id)
  end
end
