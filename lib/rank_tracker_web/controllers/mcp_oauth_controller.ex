defmodule RankTrackerWeb.McpOAuthController do
  use RankTrackerWeb, :controller

  alias RankTracker.Mcp.OAuth
  alias RankTracker.Accounts

  def discovery(conn, _params) do
    base_url = RankTrackerWeb.Endpoint.url()

    metadata = %{
      issuer: base_url,
      authorization_endpoint: "#{base_url}/oauth/authorize",
      token_endpoint: "#{base_url}/oauth/token",
      registration_endpoint: "#{base_url}/oauth/register",
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      token_endpoint_auth_methods_supported: ["client_secret_post", "none"],
      code_challenge_methods_supported: ["S256"],
      scopes_supported: ["rank_tracker"]
    }

    json(conn, metadata)
  end

  def register(conn, params) do
    redirect_uris = params["redirect_uris"] || []

    if redirect_uris == [] do
      conn |> put_status(400) |> json(%{error: "redirect_uris required"})
    else
      {:ok, client} = OAuth.register_client(redirect_uris)

      json(conn, %{
        client_id: client.client_id,
        client_secret: client.client_secret,
        redirect_uris: redirect_uris,
        grant_types: ["authorization_code"],
        token_endpoint_auth_method: "client_secret_post"
      })
    end
  end

  def authorize(conn, params) do
    client_id = params["client_id"]
    redirect_uri = params["redirect_uri"]
    state = params["state"]
    code_challenge = params["code_challenge"]
    _code_challenge_method = params["code_challenge_method"]

    user = conn.assigns[:current_user]

    cond do
      is_nil(client_id) or is_nil(redirect_uri) ->
        conn |> put_status(400) |> json(%{error: "client_id and redirect_uri required"})

      is_nil(user) ->
        return_to =
          "/oauth/authorize?" <> URI.encode_query(params)

        conn
        |> put_session(:oauth_return_to, return_to)
        |> redirect(to: ~p"/auth/login")

      true ->
        code = OAuth.create_code(user.id, client_id, redirect_uri, code_challenge)

        redirect_with_code =
          redirect_uri
          |> URI.parse()
          |> append_query_params(%{"code" => code, "state" => state})
          |> URI.to_string()

        redirect(conn, external: redirect_with_code)
    end
  end

  def token(conn, params) do
    grant_type = params["grant_type"]
    code = params["code"]
    client_id = params["client_id"]
    redirect_uri = params["redirect_uri"]
    code_verifier = params["code_verifier"]

    if grant_type != "authorization_code" do
      conn
      |> put_status(400)
      |> json(%{error: "unsupported_grant_type"})
    else
      case OAuth.exchange_code(code, client_id, redirect_uri, code_verifier) do
        {:ok, user_id} ->
          user = Accounts.get(user_id)

          if user do
            json(conn, %{
              access_token: user.api_token,
              token_type: "Bearer",
              scope: "rank_tracker"
            })
          else
            conn |> put_status(400) |> json(%{error: "invalid_grant"})
          end

        {:error, reason} ->
          conn
          |> put_status(400)
          |> json(%{error: "invalid_grant", error_description: to_string(reason)})
      end
    end
  end

  defp append_query_params(uri, params) do
    existing = URI.decode_query(uri.query || "")
    merged = Map.merge(existing, params)
    %{uri | query: URI.encode_query(merged)}
  end
end
