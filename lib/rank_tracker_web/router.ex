defmodule RankTrackerWeb.Router do
  use RankTrackerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RankTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RankTrackerWeb.Plugs.FetchCurrentUser
  end

  pipeline :browser_no_csrf do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RankTrackerWeb.Layouts, :root}
    plug :put_secure_browser_headers
    plug RankTrackerWeb.Plugs.FetchCurrentUser
  end

  pipeline :require_auth do
    plug RankTrackerWeb.Plugs.RequireAuthentication
  end

  pipeline :mcp_api do
    plug RankTracker.Mcp.AcceptHeaderPlug
    plug :accepts, ["json", "text/event-stream"]
    plug RankTracker.Mcp.AuthPlug
    plug RankTracker.Mcp.AutoInitPlug
    plug RankTracker.Mcp.DebugPlug
  end

  pipeline :oauth_api do
    plug :accepts, ["json"]
  end

  scope "/", RankTrackerWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/auth/login", AuthController, :login
    get "/auth/callback", AuthController, :callback
    delete "/auth/logout", AuthController, :logout
  end

  if Application.compile_env(:rank_tracker, :dev_routes) do
    scope "/dev", RankTrackerWeb do
      pipe_through :browser
      get "/login", AuthController, :dev_login
    end
  end

  scope "/", RankTrackerWeb do
    pipe_through [:browser, :require_auth]

    live_session :authenticated,
      on_mount: [{RankTrackerWeb.Live.Hooks.AssignUser, :default}] do
      live "/dashboard", DashboardLive, :index
      live "/domains/:id", DomainLive, :show
      live "/domains/:domain_id/keywords/new", AddKeywordsLive, :new
      live "/history/:id", HistoryLive, :show
      live "/billing", BillingLive, :index
      live "/connect", ConnectLive, :index
    end
  end

  # OAuth 2.0 endpoints for MCP authorization
  scope "/.well-known", RankTrackerWeb do
    pipe_through :oauth_api
    get "/oauth-authorization-server", McpOAuthController, :discovery
  end

  scope "/oauth", RankTrackerWeb do
    pipe_through :oauth_api
    post "/register", McpOAuthController, :register
    post "/token", McpOAuthController, :token
  end

  scope "/oauth", RankTrackerWeb do
    pipe_through :browser_no_csrf
    get "/authorize", McpOAuthController, :authorize
  end

  pipeline :stripe_webhook do
    plug :accepts, ["json"]
  end

  scope "/webhooks", RankTrackerWeb do
    pipe_through :stripe_webhook
    post "/stripe", StripeController, :webhook
  end

  scope "/mcp" do
    pipe_through :mcp_api

    forward "/", Hermes.Server.Transport.StreamableHTTP.Plug, server: RankTracker.Mcp.Server
  end
end
