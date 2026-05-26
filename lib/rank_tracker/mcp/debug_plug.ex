defmodule RankTracker.Mcp.DebugPlug do
  @moduledoc false

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    method = extract_method(conn.body_params)
    session = get_req_header(conn, "mcp-session-id") |> List.first("none")

    Logger.info("[MCP] #{conn.method} method=#{method} session=#{session}")

    register_before_send(conn, fn conn ->
      Logger.info("[MCP] #{conn.method} method=#{method} status=#{conn.status} session=#{session}")
      conn
    end)
  end

  defp extract_method(%{"method" => method}), do: method
  defp extract_method(_), do: "unknown"
end
