defmodule DriversSeatCoop.OneSignal do
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
  alias DriversSeatCoop.OneSignal.NonTemplateMessageParams

  @url "https://onesignal.com/api/v1/notifications"

  def send_notification_goals_check_progress(%User{} = user) do
    send_notification(user, :cta_goals_check_progress, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: "Track your earnings goals!",
      body:
        "Check out the Earnings tab in Driver's Seat to monitor how you are doing against your earnings goal."
    })
  end

  def send_notification_goals_link_accounts(%User{} = user) do
    send_notification(user, :cta_goals_link_accounts, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: "New: Set & track your earnings goals!",
      body:
        "We just added a new feature that lets you monitor progress against your earnings goals on Driver's Seat. Connect a gig account to get started!"
    })
  end

  def send_notification_goals_set_goals(%User{} = user) do
    send_notification(user, :cta_goals_set_goals, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: "New: Set & track your earnings goals!",
      body:
        "Check out the Earnings tab in Driver's Seat to set a new earnings goal and monitor your progress as you work."
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
    send_notification(user, :cta_earnings_insights, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title:
        "Join #{Number.Delimit.number_to_delimited(count_users_with_jobs, precision: 0)} others on Driver's Seat",
      body:
        "Other gig workers like you are getting insights into their earnings. Click here to learn more.",
      additional_data: %{
        count_users_with_jobs: count_users_with_jobs
      }
    })
  end

  def send_cta_welcome_to_community_insights_no_metro(
        %User{} = user,
        count_users_with_community_insights
      ) do
    send_notification(user, :cta_community_insights, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title:
        "#{Number.Delimit.number_to_delimited(count_users_with_community_insights, precision: 0)} workers share earning tips!",
      body:
        "Visit the Insights tab to see what gig workers in nearby areas have been earning, for different apps and times of day.",
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
    title =
      if metro_area.count_workers < 5,
        do: "Learn from other workers nearby!",
        else:
          "Learn from #{Number.Delimit.number_to_delimited(metro_area.count_workers, precision: 0)} workers nearby!"

    send_notification(user, :cta_community_insights, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: title,
      body:
        "Driver's Seat tracks what other gig workers in your area have been earning recently. Check the Insights tab to see the top gig apps and times with the highest earnings rates.",
      additional_data: %{
        metro_area: metro_area.name,
        count_workers_in_metro: metro_area.count_workers,
        metro_has_enough_data: true,
        user_has_activities: has_activity_data
      }
    })
  end

  # Metro DOES NOT have enough data and the user HAS NOT registered their argyle accounts
  def send_cta_welcome_to_community_insights_has_metro(
        %User{} = user,
        metro_area,
        false = _enough_data,
        false = _has_activity_data
      ) do
    title =
      if metro_area.count_workers < 5,
        do: "Your community needs you!",
        else:
          "#{Number.Delimit.number_to_delimited(metro_area.count_workers, precision: 0)} workers nearby need you!"

    send_notification(user, :cta_community_insights, %NonTemplateMessageParams{
      include_external_user_ids: [user.id],
      title: title,
      body:
        "Gig workers in your area are working together to track how much the gig apps are paying. You can contribute data, and get back insights, by connecting your gig apps.",
      additional_data: %{
        metro_area: metro_area.name,
        count_workers: metro_area.count_workers,
        metro_has_enough_data: false,
        user_has_activities: false
      }
    })
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
      send_notification(user, :start_shift_reminder, %NonTemplateMessageParams{
        include_external_user_ids: [user.id],
        title: "Start Shift in Driver's Seat",
        body:
          "Reminder: It's time to start your shift on Driver's Seat! Push the 'Start Shift' button when you start working so your total work time and mileage are captured.",
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
      send_notification(user, :end_shift_reminder, %NonTemplateMessageParams{
        include_external_user_ids: [user.id],
        title: "Complete your shift in Driver's Seat",
        body:
          "Remember to end your shift in Driver's Seat! When you're done working, turn off the shift tracker so your total work time and mileage are accurately captured.",
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
      send_notification(user, :argyle_activities_available, %NonTemplateMessageParams{
        include_external_user_ids: [user.id],
        title: "Your Data is Ready",
        body:
          "Hi #{user.first_name || "there"},  Your work data is ready to be viewed in Driver's Seat!"
      })
    else
      {:ok, :user_cannot_receive_notification}
    end
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
