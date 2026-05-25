defmodule RankTracker.Mcp.Server do
  use Hermes.Server,
    name: "SEO Rank Tracker",
    version: "0.2.0",
    capabilities: [:tools]

  alias RankTracker.Mcp.Tools

  component(Tools.ListDomains, name: "list_domains")
  component(Tools.AddDomain, name: "add_domain")
  component(Tools.AddKeywords, name: "add_keywords")
  component(Tools.ListKeywords, name: "list_keywords")
  component(Tools.RefreshRanks, name: "refresh_ranks")
  component(Tools.GetHistory, name: "get_history")
  component(Tools.CheckRank, name: "check_rank")
  component(Tools.CheckRanks, name: "check_ranks")
  component(Tools.GetBalance, name: "get_balance")

  @impl true
  def init(_client_info, frame) do
    {:ok, assign(frame, :ready_at, DateTime.utc_now())}
  end
end
