defmodule RankTracker.Mcp.AcceptHeaderPlug do
  @moduledoc """
  Ensures the Accept header includes both application/json and text/event-stream,
  as required by the MCP Streamable HTTP specification (and enforced by Hermes).

  Some MCP clients (e.g., Claude Code) may only send Accept: application/json,
  which causes Hermes to reject requests with 406 before tools can be listed.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    accept = get_req_header(conn, "accept") |> List.first("")

    if String.contains?(accept, "application/json") and
         not String.contains?(accept, "text/event-stream") do
      put_req_header(conn, "accept", accept <> ", text/event-stream")
    else
      conn
    end
  end
end
