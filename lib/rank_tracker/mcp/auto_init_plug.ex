defmodule RankTracker.Mcp.AutoInitPlug do
  @moduledoc """
  Auto-marks MCP sessions as initialized after a successful `initialize` response.

  Some MCP clients (e.g., Claude Code) don't send the `notifications/initialized`
  notification required by the protocol. Without it, the Hermes server rejects all
  subsequent requests with "Server not initialized". This plug works around that by
  calling Session.mark_initialized directly after the initialize handshake completes.
  """

  import Plug.Conn

  alias Hermes.Server.Registry, as: McpRegistry
  alias Hermes.Server.Session

  def init(opts), do: opts

  def call(conn, _opts) do
    if initialize_request?(conn.body_params) do
      register_before_send(conn, fn conn ->
        if conn.status == 200, do: mark_session_initialized(conn)
        conn
      end)
    else
      conn
    end
  end

  defp initialize_request?(%{"method" => "initialize"}), do: true
  defp initialize_request?(_), do: false

  defp mark_session_initialized(conn) do
    case get_resp_header(conn, "mcp-session-id") do
      [session_id] ->
        session_name = McpRegistry.server_session(RankTracker.Mcp.Server, session_id)
        Session.mark_initialized(session_name)

      _ ->
        :ok
    end
  end
end
