defmodule RankTracker.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RankTrackerWeb.Telemetry,
      RankTracker.Repo,
      {DNSCluster, query: Application.get_env(:rank_tracker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RankTracker.PubSub},
      {Task.Supervisor, name: RankTracker.TaskSupervisor},
      RankTracker.RankChecker,
      Hermes.Server.Registry,
      {RankTracker.Mcp.Server, transport: {:streamable_http, [start: true]}, request_timeout: 180_000},
      RankTrackerWeb.Endpoint
    ]

    RankTracker.Mcp.OAuth.init()

    opts = [strategy: :one_for_one, name: RankTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RankTrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
