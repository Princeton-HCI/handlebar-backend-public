defmodule DriversSeatCoopWeb.Router do
  use DriversSeatCoopWeb, :router

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:browser]

      forward "/mailbox", Plug.Swoosh.MailboxPreview, base_path: "/dev/mailbox"
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug DriversSeatCoopWeb.AppDowntimePlug, false
    plug DriversSeatCoopWeb.OutOfDateAppVersionPlug
  end

  pipeline :authenticated do
    plug DriversSeatCoopWeb.AuthenticationPlug
    plug DriversSeatCoopWeb.AppDowntimePlug, true
    plug DriversSeatCoopWeb.DeviceInfoPlug
    plug DriversSeatCoopWeb.OutOfDateAppVersionPlug
  end

  pipeline :authenticated_and_terms_required do
    plug DriversSeatCoopWeb.AuthenticationPlug
    plug DriversSeatCoopWeb.AppDowntimePlug, true
    plug DriversSeatCoopWeb.DeviceInfoPlug
    plug DriversSeatCoopWeb.OutOfDateAppVersionPlug
    plug DriversSeatCoopWeb.LatestTermsPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :admin_auth do
    plug DriversSeatCoopWeb.AdminAuthenticationPlug
  end

  pipeline :admin_only do
    plug DriversSeatCoopWeb.AuthenticationPlug
    plug DriversSeatCoopWeb.AdminOnlyPlug
  end

  scope "/", DriversSeatCoopWeb.Web, as: :web do
    pipe_through :browser

    resources "/reset_password", ResetPasswordController, only: [:edit, :update]
  end

  scope "/_admin", DriversSeatCoopWeb.Admin, as: :admin do
    pipe_through :browser

    resources "/sessions", SessionController, only: [:new, :create]

    scope "/" do
      pipe_through :admin_auth

      resources "/", PageController, only: [:index]
      delete "/logout", SessionController, :logout
      resources "/terms", TermsController
      resources "/accepted_terms", AcceptedTermsController
      resources "/research_groups", ResearchGroupController
      resources "/users", UserController
      post "/users/burninate/:id", UserController, :burninate
      post "/users/sync_argyle/:id", UserController, :sync_argyle

      # no editing jobs or creating new jobs, only cancelling, retrying, and
      # deleting them
      get "/oban/jobs", ObanJobController, :index
      get "/oban/jobs/:id", ObanJobController, :show
      post "/oban/jobs/:id/cancel", ObanJobController, :cancel
      post "/oban/jobs/:id/retry", ObanJobController, :retry
      delete "/oban/jobs/:id", ObanJobController, :delete
    end
  end

  scope "/api", DriversSeatCoopWeb do
    pipe_through :api

    resources "/users", UserController, only: [:create]
    get "/users/lookup/:email", UserController, :lookup
    resources "/sessions", SessionController, only: [:create]
    resources "/reset_password", ResetPasswordController, only: [:create]
    get "/research_groups/lookup/:code", ResearchGroupController, :lookup
    get "/referral_source/lookup/:code", ReferralSourceController, :lookup
    get "/terms/public", TermsController, :public
    post "/help/request/public", HelpController, :create

    post "/argyle_event_webhook", ArgyleWebhookController, :create

    scope "/" do
      pipe_through :authenticated

      get "/terms/current", TermsController, :current
      resources "/terms", TermsController, only: [:show]
      resources "/accepted_terms", AcceptedTermsController, only: [:index, :create, :show]
      resources "/sessions", SessionController, only: [:index]
      resources "/users", UserController, only: [:show, :update, :delete]
      resources "/data_request", DataRequestController, only: [:create]
      resources "/argyle_user", ArgyleUserController
      resources "/app_preferences", AppPreferencesController, only: [:index, :update]
      post "/help/request/authenticated", HelpController, :create
    end

    scope "/" do
      pipe_through :authenticated_and_terms_required

      resources "/points", PointController, only: [:create]

      resources "/referral_source", ReferralSourceController, [:index, :show]
      resources "/shift", ShiftController
      resources "/scheduled_shifts", ScheduledShiftController, only: [:index, :create]
      get "/user_pay_performance/:user_id", EarningsController, :summary
      post "/user_pay_performance/export", EarningsController, :export

      resources "/regions/metro_areas", MetroAreaController, only: [:index]
      resources "/employers", EmployerController, only: [:index]
      post "/analytics/hourly_pay/summary", AverageHourlyPayStatsController, :summary
      post "/analytics/hourly_pay/trend", AverageHourlyPayStatsController, :trend

      post "/shift/update_working_time/:work_date", ShiftController, :update_working_time

      resources "/expenses", ExpenseController
      post "/expenses/export", ExpenseController, :export

      scope "/earnings" do
        get "/summary/:level/latest", EarningsController, :summary_latest
        get "/summary", EarningsController, :summary
        get "/work_time/:work_date", EarningsController, :detail
        get "/work_time", EarningsController, :index
        get "/activities/", EarningsController, :activity_index
        get "/activities/:activity_id", EarningsController, :activity
        post "/export", EarningsController, :export
      end

      scope "/marketing" do
        get "/campaigns", MarketingController, :index
        post "/campaigns/:campaign", MarketingController, :save
        post "/campaigns/:campaign/presented", MarketingController, :present
        post "/campaigns/:campaign/accepted", MarketingController, :accept
        post "/campaigns/:campaign/postponed", MarketingController, :postpone
        post "/campaigns/:campaign/dismissed", MarketingController, :dismiss
        post "/campaigns/:campaign/custom", MarketingController, :custom
        get "/onboarding_status", MarketingController, :onboarding_status
      end

      scope "/goals" do
        get "/:frequency", GoalsController, :index
        post "/:type/:frequency/:start_date", GoalsController, :save
        delete "/:type/:frequency/:start_date", GoalsController, :delete

        scope "/performance" do
          get "/:frequency/:window_date", GoalsController, :performance
        end
      end

      scope "/crepe" do
        resources "/collectors", CrepeCollectorController, only: [:index]
      end
    end

    scope "/_admin" do
      pipe_through :admin_only
      post "/ghost_user", SessionController, :ghost_admin_user
    end
  end
end
