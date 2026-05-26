defmodule RankTracker.Mcp.AcceptHeaderPlug do
  @moduledoc """
  Normalizes the Accept header for MCP Streamable HTTP requests.

  Hermes requires POST requests to include both application/json and
  text/event-stream. Phoenix's :accepts plug requires a recognized format
  (like "json") for GET requests. This plug ensures both sides are satisfied.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    accept = get_req_header(conn, "accept") |> List.first("")

    cond do
      String.contains?(accept, "application/json") and
          not String.contains?(accept, "text/event-stream") ->
        put_req_header(conn, "accept", accept <> ", text/event-stream")

      String.contains?(accept, "text/event-stream") and
          not String.contains?(accept, "application/json") ->
        put_req_header(conn, "accept", "application/json, " <> accept)

      true ->
        conn
    end
  end
end
