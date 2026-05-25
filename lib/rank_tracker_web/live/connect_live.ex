defmodule RankTrackerWeb.ConnectLive do
  use RankTrackerWeb, :live_view

  def mount(_params, _session, socket) do
    base_url = RankTrackerWeb.Endpoint.url()
    api_token = socket.assigns.current_user.api_token

    {:ok,
     assign(socket,
       page_title: "Connect AI Agent",
       base_url: base_url,
       api_token: api_token,
       show_token: false,
       selected_client: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <div class="mb-12">
        <span class="section-label">Integrations</span>
        <h1 class="text-2xl font-light text-[oklch(8%_0.005_260)] mt-1">
          Connect AI Agent
        </h1>
        <p class="text-sm text-[oklch(50%_0.005_260)] mt-2 max-w-lg leading-relaxed">
          Connect your AI assistant to SEO Rank Tracker via MCP.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-5 gap-8">
        <%!-- Left: tools + credentials --%>
        <div class="lg:col-span-3">
          <h2 class="font-mono text-xs uppercase tracking-wider text-[oklch(45%_0.005_260)] mb-4">
            Available Tools
          </h2>
          <div class="mb-10">
            <.tool_row name="list_domains" desc="List all tracked domains" />
            <.tool_row name="add_domain" desc="Add a new domain to track" />
            <.tool_row name="add_keywords" desc="Add keywords + countries to a domain" />
            <.tool_row name="list_keywords" desc="List combos with latest positions" />
            <.tool_row name="refresh_ranks" desc="Refresh all rankings for a domain" />
            <.tool_row name="get_history" desc="Get rank history for a combination" />
            <.tool_row name="check_rank" desc="Live rank check (single, not stored)" />
            <.tool_row name="check_ranks" desc="Live batch rank check (not stored)" />
            <.tool_row name="get_balance" desc="Check wallet balance" />
          </div>

          <h2 class="font-mono text-xs uppercase tracking-wider text-[oklch(45%_0.005_260)] mb-4">
            Your Credentials
          </h2>
          <div class="border border-[oklch(90%_0.005_260)] p-4 space-y-3">
            <div>
              <span class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] uppercase">
                Server URL
              </span>
              <div class="font-mono text-sm text-[oklch(12%_0.005_260)] mt-0.5 select-all">
                {@base_url}/mcp
              </div>
            </div>
            <div>
              <span class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] uppercase">
                API Token
              </span>
              <div class="flex items-center gap-2 mt-0.5">
                <%= if @show_token do %>
                  <code class="font-mono text-xs text-[oklch(12%_0.005_260)] select-all break-all">
                    {@api_token}
                  </code>
                <% else %>
                  <code class="font-mono text-xs text-[oklch(55%_0.005_260)]">
                    ************************************
                  </code>
                <% end %>
                <button phx-click="toggle_token" class="btn-action text-[0.625rem] py-0.5 px-2">
                  {if @show_token, do: "Hide", else: "Reveal"}
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Right: Install sidebar --%>
        <div class="lg:col-span-2">
          <div class="border border-[oklch(88%_0.005_260)] bg-[oklch(98.5%_0.002_260)] sticky top-6">
            <div class="px-4 py-3 border-b border-[oklch(90%_0.005_260)]">
              <%= if @selected_client do %>
                <button
                  phx-click="back_to_clients"
                  class="font-mono text-xs text-[oklch(50%_0.005_260)] hover:text-[oklch(25%_0.005_260)] transition-colors"
                >
                  &larr; All clients
                </button>
              <% else %>
                <span class="font-mono text-xs uppercase tracking-wider text-[oklch(40%_0.005_260)]">
                  Install
                </span>
              <% end %>
            </div>

            <%= if @selected_client do %>
              <.install_detail
                client={@selected_client}
                base_url={@base_url}
                api_token={@api_token}
                show_token={@show_token}
              />
            <% else %>
              <div class="divide-y divide-[oklch(92%_0.003_260)]">
                <.client_row
                  id="cursor"
                  name="Cursor"
                  action="One-click install"
                  badge="1-Click"
                />
                <.client_row
                  id="vscode"
                  name="VS Code"
                  action="One-click install"
                  badge="1-Click"
                />
                <.client_row
                  id="claude-desktop"
                  name="Claude Desktop"
                  action="Copy configuration"
                />
                <.client_row
                  id="claude-code"
                  name="Claude Code"
                  action="Copy CLI command"
                  badge="CLI"
                />
                <.client_row id="windsurf" name="Windsurf" action="Copy configuration" />
                <.client_row
                  id="oauth"
                  name="OAuth (any client)"
                  action="Auto-discover endpoints"
                />
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle_token", _, socket) do
    {:noreply, assign(socket, show_token: !socket.assigns.show_token)}
  end

  def handle_event("select_client", %{"client" => client}, socket) do
    {:noreply, assign(socket, selected_client: client)}
  end

  def handle_event("back_to_clients", _, socket) do
    {:noreply, assign(socket, selected_client: nil)}
  end

  # Components

  attr :name, :string, required: true
  attr :desc, :string, required: true

  defp tool_row(assigns) do
    ~H"""
    <div class="flex items-baseline gap-3 py-1.5">
      <code class="font-mono text-xs font-medium text-[oklch(12%_0.005_260)] w-32 shrink-0">
        {@name}
      </code>
      <span class="text-sm text-[oklch(50%_0.005_260)]">{@desc}</span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :action, :string, required: true
  attr :badge, :string, default: nil

  defp client_row(assigns) do
    ~H"""
    <button
      phx-click="select_client"
      phx-value-client={@id}
      class="w-full flex items-center justify-between px-4 py-3 hover:bg-[oklch(96%_0.003_260)] transition-colors text-left"
    >
      <div>
        <div class="text-sm font-medium text-[oklch(15%_0.005_260)]">{@name}</div>
        <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)]">{@action}</div>
      </div>
      <div class="flex items-center gap-2">
        <%= if @badge do %>
          <span class="font-mono text-[0.5625rem] px-1.5 py-0.5 bg-[oklch(42%_0.16_155)] text-[oklch(98%_0.005_260)]">
            {@badge}
          </span>
        <% end %>
        <span class="text-[oklch(70%_0.005_260)]">&rsaquo;</span>
      </div>
    </button>
    """
  end

  attr :client, :string, required: true
  attr :base_url, :string, required: true
  attr :api_token, :string, required: true
  attr :show_token, :boolean, required: true

  defp install_detail(assigns) do
    assigns = assign(assigns, :token, assigns.api_token)

    ~H"""
    <div class="p-4">
      <%= case @client do %>
        <% "cursor" -> %>
          <div class="text-sm font-medium text-[oklch(15%_0.005_260)] mb-1">Cursor</div>
          <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] mb-3">
            One-click install
          </div>
          <a
            href={cursor_install_url(@base_url, @api_token)}
            class="btn-action btn-action-primary w-full block text-center mb-4"
          >
            Install in Cursor
          </a>
          <p class="text-xs text-[oklch(50%_0.005_260)] mb-2">
            Or add this to <code class="font-mono">~/.cursor/mcp.json</code>:
          </p>
          <.code_block content={config_with_headers(@base_url, @token)} />
        <% "vscode" -> %>
          <div class="text-sm font-medium text-[oklch(15%_0.005_260)] mb-1">VS Code</div>
          <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] mb-3">
            One-click install
          </div>
          <a
            href={vscode_install_url(@base_url, @api_token)}
            class="btn-action btn-action-primary w-full block text-center mb-4"
          >
            Install in VS Code
          </a>
          <p class="text-xs text-[oklch(50%_0.005_260)] mb-2">
            Or add this to <code class="font-mono">.vscode/mcp.json</code>:
          </p>
          <.code_block content={config_with_headers(@base_url, @token)} />
        <% "claude-desktop" -> %>
          <div class="text-sm font-medium text-[oklch(15%_0.005_260)] mb-1">Claude Desktop</div>
          <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] mb-3">
            JSON configuration
          </div>
          <p class="text-xs text-[oklch(50%_0.005_260)] mb-2">
            Add this to <code class="font-mono">claude_desktop_config.json</code>:
          </p>
          <.code_block content={config_with_headers(@base_url, @token)} />
          <div class="mt-3 border-t border-[oklch(92%_0.003_260)] pt-3">
            <div class="flex items-start gap-2">
              <span class="text-[oklch(42%_0.16_155)] text-xs mt-0.5">&#10003;</span>
              <div>
                <div class="text-xs font-medium text-[oklch(35%_0.005_260)]">Prerequisite</div>
                <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)]">
                  Claude Desktop app installed
                </div>
              </div>
            </div>
          </div>
        <% "claude-code" -> %>
          <div class="text-sm font-medium text-[oklch(15%_0.005_260)] mb-1">Claude Code</div>
          <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] mb-3">
            Terminal command
          </div>
          <p class="text-xs text-[oklch(50%_0.005_260)] mb-2">
            Copy and run this in your terminal:
          </p>
          <.code_block content={claude_code_command(@base_url, @token)} />
          <p class="text-xs text-[oklch(50%_0.005_260)] mt-3 mb-2">
            Or add to <code class="font-mono">.mcp.json</code>:
          </p>
          <.code_block content={config_with_type(@base_url, @token)} />
          <div class="mt-3 border-t border-[oklch(92%_0.003_260)] pt-3">
            <div class="flex items-start gap-2">
              <span class="text-[oklch(42%_0.16_155)] text-xs mt-0.5">&#10003;</span>
              <div>
                <div class="text-xs font-medium text-[oklch(35%_0.005_260)]">Prerequisite</div>
                <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)]">
                  Claude Code CLI installed
                </div>
              </div>
            </div>
          </div>
        <% "windsurf" -> %>
          <div class="text-sm font-medium text-[oklch(15%_0.005_260)] mb-1">Windsurf</div>
          <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] mb-3">
            JSON configuration
          </div>
          <p class="text-xs text-[oklch(50%_0.005_260)] mb-2">
            Add this to <code class="font-mono">~/.codeium/windsurf/mcp_config.json</code>:
          </p>
          <.code_block content={config_windsurf(@base_url, @token)} />
        <% "oauth" -> %>
          <div class="text-sm font-medium text-[oklch(15%_0.005_260)] mb-1">
            OAuth (any client)
          </div>
          <div class="font-mono text-[0.625rem] text-[oklch(55%_0.005_260)] mb-3">
            Auto-discover endpoints
          </div>
          <p class="text-xs text-[oklch(50%_0.005_260)] mb-2">
            Just use the server URL — no token needed:
          </p>
          <.code_block content={config_oauth(@base_url)} />
          <div class="mt-3 text-xs text-[oklch(50%_0.005_260)] space-y-1">
            <p>The client will automatically:</p>
            <ol class="list-decimal list-inside space-y-0.5 text-[oklch(45%_0.005_260)]">
              <li>Register dynamically</li>
              <li>Open browser to sign in</li>
              <li>Exchange code for token</li>
            </ol>
          </div>
        <% _ -> %>
          <p>Unknown client</p>
      <% end %>
    </div>
    """
  end

  attr :content, :string, required: true

  defp code_block(assigns) do
    ~H"""
    <div class="bg-[oklch(14%_0.005_260)] p-3 overflow-x-auto">
      <pre class="font-mono text-[0.6875rem] text-[oklch(75%_0.005_260)] leading-relaxed">{@content}</pre>
    </div>
    """
  end

  defp token_display(token, true), do: token
  defp token_display(_token, false), do: "YOUR_API_TOKEN"

  defp cursor_install_url(base_url, api_token) do
    config =
      Jason.encode!(%{
        "url" => "#{base_url}/mcp",
        "headers" => %{"Authorization" => "Bearer #{api_token}"}
      })

    encoded = Base.encode64(config)

    "cursor://anysphere.cursor-deeplink/mcp/install?name=seo-rank-tracker&config=#{URI.encode(encoded)}"
  end

  defp vscode_install_url(base_url, api_token) do
    config =
      Jason.encode!(%{
        "name" => "seo-rank-tracker",
        "url" => "#{base_url}/mcp",
        "headers" => %{"Authorization" => "Bearer #{api_token}"}
      })

    "vscode:mcp/install?#{URI.encode(config)}"
  end

  defp claude_code_command(base_url, token) do
    "claude mcp add seo-rank-tracker --transport http #{base_url}/mcp --header \"Authorization: Bearer #{token}\""
  end

  defp config_with_headers(base_url, token) do
    """
    {
      "mcpServers": {
        "seo-rank-tracker": {
          "url": "#{base_url}/mcp",
          "headers": {
            "Authorization": "Bearer #{token}"
          }
        }
      }
    }\
    """
  end

  defp config_with_type(base_url, token) do
    """
    {
      "mcpServers": {
        "seo-rank-tracker": {
          "type": "url",
          "url": "#{base_url}/mcp",
          "headers": {
            "Authorization": "Bearer #{token}"
          }
        }
      }
    }\
    """
  end

  defp config_windsurf(base_url, token) do
    """
    {
      "mcpServers": {
        "seo-rank-tracker": {
          "serverUrl": "#{base_url}/mcp",
          "headers": {
            "Authorization": "Bearer #{token}"
          }
        }
      }
    }\
    """
  end

  defp config_oauth(base_url) do
    """
    {
      "mcpServers": {
        "seo-rank-tracker": {
          "url": "#{base_url}/mcp"
        }
      }
    }\
    """
  end
end
