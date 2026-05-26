defmodule RankTracker.Mcp.TransportPlug do
  @moduledoc """
  Custom MCP transport plug that wraps Hermes StreamableHTTP.

  For GET and DELETE requests, delegates to the Hermes plug as-is (SSE, cleanup).
  For POST requests, bypasses the strict Accept header validation and SSE routing
  so responses are always returned in the HTTP body (not routed via SSE stream).
  This fixes compatibility with clients like Claude Code.
  """

  @behaviour Plug

  import Plug.Conn

  require Logger

  alias Hermes.MCP.ID
  alias Hermes.MCP.Message
  alias Hermes.Server.Transport.StreamableHTTP

  require Message

  @session_header "mcp-session-id"

  @impl Plug
  def init(opts) do
    server = Keyword.fetch!(opts, :server)
    registry = Keyword.get(opts, :registry, Hermes.Server.Registry)
    transport = registry.transport(server, :streamable_http)

    %{transport: transport, hermes_opts: Hermes.Server.Transport.StreamableHTTP.Plug.init(opts)}
  end

  @impl Plug
  def call(conn, %{transport: transport, hermes_opts: hermes_opts}) do
    case conn.method do
      "POST" -> handle_post(conn, transport)
      _ -> Hermes.Server.Transport.StreamableHTTP.Plug.call(conn, hermes_opts)
    end
  end

  defp handle_post(conn, transport) do
    body = conn.body_params
    session_id = get_session_id(conn, body)
    context = build_context(conn)

    case StreamableHTTP.handle_message(transport, session_id, body, context) do
      {:ok, nil} ->
        conn
        |> put_resp_content_type("application/json")
        |> maybe_set_session(session_id)
        |> send_resp(202, "{}")

      {:ok, response} ->
        method = if is_map(body), do: body["method"], else: "unknown"
        Logger.info("[MCP] POST method=#{method} session=#{session_id} response=#{String.slice(to_string(response), 0..500)}")

        conn
        |> put_resp_content_type("application/json")
        |> maybe_set_session(session_id)
        |> send_resp(200, response)

      {:error, %Hermes.MCP.Error{} = error} ->
        {:ok, encoded} = Hermes.MCP.Error.to_json_rpc(error, body["id"] || ID.generate_error_id())

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, encoded)

      {:error, _reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: "internal_error"}))
    end
  end

  defp get_session_id(conn, body) do
    case get_req_header(conn, @session_header) do
      [id] when id != "" -> id
      _ ->
        if is_map(body) and body["method"] == "initialize",
          do: ID.generate_session_id(),
          else: ID.generate_session_id()
    end
  end

  defp maybe_set_session(conn, session_id) do
    if get_req_header(conn, @session_header) == [] do
      put_resp_header(conn, @session_header, session_id)
    else
      conn
    end
  end

  defp build_context(conn) do
    %{
      assigns: conn.assigns,
      type: :http,
      req_headers: conn.req_headers,
      remote_ip: conn.remote_ip,
      scheme: conn.scheme,
      host: conn.host,
      port: conn.port,
      request_path: conn.request_path
    }
  end
end
