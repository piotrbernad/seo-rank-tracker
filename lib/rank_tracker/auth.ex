defmodule RankTracker.Auth do
  alias RankTracker.Auth.HTTPClient

  @type config :: %{
          required(:domain) => String.t(),
          required(:client_id) => String.t(),
          optional(:client_secret) => String.t(),
          required(:redirect_uri) => String.t(),
          optional(:scope) => String.t()
        }

  @spec config() :: config
  def config do
    Application.fetch_env!(:rank_tracker, __MODULE__)
    |> Map.new()
  end

  @spec authorization_url(String.t(), String.t()) :: String.t()
  def authorization_url(state, code_challenge) do
    cfg = config()

    query =
      URI.encode_query(%{
        "response_type" => "code",
        "client_id" => cfg.client_id,
        "redirect_uri" => cfg.redirect_uri,
        "scope" => cfg.scope || "openid profile email",
        "state" => state,
        "code_challenge" => code_challenge,
        "code_challenge_method" => "S256"
      })

    %URI{scheme: "https", host: cfg.domain, path: "/authorize", query: query}
    |> URI.to_string()
  end

  @spec exchange_code(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def exchange_code(code, code_verifier, redirect_uri) do
    cfg = config()

    body =
      URI.encode_query(%{
        "grant_type" => "authorization_code",
        "client_id" => cfg.client_id,
        "client_secret" => cfg.client_secret,
        "code" => code,
        "code_verifier" => code_verifier,
        "redirect_uri" => redirect_uri
      })

    url = "https://#{cfg.domain}/oauth/token"

    HTTPClient.request(:post, url, body, [{"content-type", "application/x-www-form-urlencoded"}])
  end

  @spec userinfo(String.t()) :: {:ok, map()} | {:error, term()}
  def userinfo(access_token) do
    cfg = config()
    url = "https://#{cfg.domain}/userinfo"
    HTTPClient.request(:get, url, "", [{"authorization", "Bearer #{access_token}"}])
  end

  @spec logout_url(String.t()) :: String.t()
  def logout_url(return_to) do
    cfg = config()

    query =
      URI.encode_query(%{
        "client_id" => cfg.client_id,
        "returnTo" => return_to
      })

    %URI{scheme: "https", host: cfg.domain, path: "/v2/logout", query: query}
    |> URI.to_string()
  end
end
