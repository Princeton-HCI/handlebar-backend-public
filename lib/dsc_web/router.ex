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

  pipeline :group_member_only do
    plug DriversSeatCoopWeb.EnsureGroupMemberPlug
  end

  pipeline :researcher_only do
    plug DriversSeatCoopWeb.ResearcherPlug
  end

  scope "/", DriversSeatCoopWeb.Web, as: :web do
    pipe_through :browser

    get "/", PageController, :index
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
      resources "/users", UserController
      post "/users/burninate/:id", UserController, :burninate

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
    get "/terms/public", TermsController, :public
    post "/help/request/public", HelpController, :create

    scope "/research" do
      get "/groups/lookup/:code", ResearchGroupController, :lookup
    end

    scope "/" do
      pipe_through :authenticated

      get "/terms/current", TermsController, :current
      resources "/terms", TermsController, only: [:show]
      resources "/accepted_terms", AcceptedTermsController, only: [:index, :create, :show]
      resources "/sessions", SessionController, only: [:index]
      resources "/users", UserController, only: [:show, :update, :delete]
      resources "/data_request", DataRequestController, only: [:create]
      post "/help/request/authenticated", HelpController, :create
    end

    scope "/research" do
      # ============================================================
      # 1. GLOBAL RESEARCH ROUTES
      # Actions that don't require membership yet (Joining, Listing personal studies)
      # ============================================================
      pipe_through :authenticated_and_terms_required

      # List groups the user is in or Create a new group
      resources "/groups", ResearchGroupController, only: [:index, :create]

      # Join a group via code
      post "/memberships/join", ResearchGroupMembershipController, :join

      # Global personal data views
      get "/me/collectors", ResearchGroupCollectorController, :index_participant
      get "/me/crepe-events", ResearchGroupCrepeEventController, :index_participant

      # Event submission (usually from background service)
      post "/crepe-event", ResearchGroupCrepeEventController, :create

      # ============================================================
      # 2. GROUP MEMBER ROUTES (Participants & Researchers)
      # Requires the user to be an active member of the group.
      # ============================================================
      scope "/" do
        pipe_through :group_member_only

        # View specific group details (protected by membership)
        get "/groups/:id", ResearchGroupController, :show

        # List ONLY researchers (The route we just added for participants)
        get "/groups/:group_id/researchers", ResearchGroupMembershipController, :index_researchers

        # View my specific membership data
        get "/groups/:group_id/membership", ResearchGroupMembershipController, :show_mine

        # List collectors allowed for this group
        get "/groups/:group_id/collectors", ResearchGroupCollectorController, :index_group

        # Membership self-service (Update policy or Leave)
        patch "/memberships/:membership_id", ResearchGroupMembershipController, :update
        delete "/memberships/:membership_id", ResearchGroupMembershipController, :leave

        scope "/" do
          pipe_through :researcher_only

          # Update group settings or Delete the study
          resources "/groups", ResearchGroupController, only: [:update, :delete]

          # Full Member Management
          get "/groups/:group_id/members", ResearchGroupMembershipController, :index
          post "/groups/:group_id/members", ResearchGroupMembershipController, :create_researcher
          delete "/groups/:group_id/members/:membership_id", ResearchGroupMembershipController, :kick

          # Collector management
          post "/groups/:group_id/collectors", ResearchGroupCollectorController, :create
          delete "/groups/:group_id/collectors/:collector_id", ResearchGroupCollectorController, :delete

          # Use LLM to translate and select graph queries
          get "/groups/:group_id/crepe-events", ResearchGroupCrepeEventController, :index_researcher_all_participants
          get "/groups/:group_id/members/:membership_id/crepe-events", ResearchGroupCrepeEventController, :index_researcher_single_participant
          post "/groups/:group_id/llm/query-selection", ResearchGroupLlmController, :select_queries
        end
      end

      resources "/points", PointController, only: [:create]

      resources "/shift", ShiftController
      resources "/scheduled_shifts", ScheduledShiftController, only: [:index, :create]
      get "/user_pay_performance/:user_id", EarningsController, :summary
      post "/user_pay_performance/export", EarningsController, :export

      resources "/regions/metro_areas", MetroAreaController, only: [:index]
      resources "/employers", EmployerController, only: [:index]

      post "/shift/update_working_time/:work_date", ShiftController, :update_working_time

      scope "/earnings" do
        get "/summary/:level/latest", EarningsController, :summary_latest
        get "/summary", EarningsController, :summary
        get "/work_time/:work_date", EarningsController, :detail
        get "/work_time", EarningsController, :index
        get "/activities/", EarningsController, :activity_index
        get "/activities/:activity_id", EarningsController, :activity
        post "/export", EarningsController, :export
      end

      scope "/goals" do
        get "/:frequency", GoalsController, :index
        post "/:type/:frequency/:start_date", GoalsController, :save
        delete "/:type/:frequency/:start_date", GoalsController, :delete

        scope "/performance" do
          get "/:frequency/:window_date", GoalsController, :performance
        end
      end
    end

    scope "/_admin" do
      pipe_through :admin_only
      post "/ghost_user", SessionController, :ghost_admin_user
    end
  end
end
