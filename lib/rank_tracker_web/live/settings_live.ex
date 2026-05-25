defmodule RankTrackerWeb.SettingsLive do
  use RankTrackerWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Settings")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto">
      <h1 class="text-2xl font-bold mb-8">Settings</h1>

      <div class="card bg-base-100 border border-base-300">
        <div class="card-body">
          <h2 class="card-title">API Token</h2>
          <p class="text-base-content/60 text-sm mb-4">
            Use this token to authenticate MCP tool calls.
          </p>
          <code class="bg-base-200 px-3 py-2 rounded text-sm font-mono break-all">
            {@current_user.api_token}
          </code>
        </div>
      </div>
    </div>
    """
  end
end
