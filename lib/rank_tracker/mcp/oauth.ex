defmodule RankTracker.Mcp.OAuth do
  @moduledoc """
  Simple OAuth 2.0 authorization server for MCP clients.
  Stores auth codes and client registrations in ETS with TTL.
  """

  @code_table :mcp_oauth_codes
  @client_table :mcp_oauth_clients
  @code_ttl_ms :timer.minutes(5)

  def init do
    if :ets.info(@code_table) == :undefined do
      :ets.new(@code_table, [:named_table, :set, :public, read_concurrency: true])
    end

    if :ets.info(@client_table) == :undefined do
      :ets.new(@client_table, [:named_table, :set, :public, read_concurrency: true])
    end

    :ok
  end

  # Client registration

  def register_client(redirect_uris) do
    init()
    client_id = random_token(16)
    client_secret = random_token(32)

    :ets.insert(
      @client_table,
      {client_id,
       %{
         client_id: client_id,
         client_secret: client_secret,
         redirect_uris: List.wrap(redirect_uris)
       }}
    )

    {:ok, %{client_id: client_id, client_secret: client_secret}}
  end

  def get_client(client_id) do
    init()

    case :ets.lookup(@client_table, client_id) do
      [{^client_id, client}] -> {:ok, client}
      [] -> :error
    end
  end

  def valid_redirect_uri?(client_id, redirect_uri) do
    case get_client(client_id) do
      {:ok, client} -> redirect_uri in client.redirect_uris
      :error -> false
    end
  end

  # Authorization codes

  def create_code(user_id, client_id, redirect_uri, code_challenge) do
    init()
    code = random_token(32)
    expires_at = System.monotonic_time(:millisecond) + @code_ttl_ms

    :ets.insert(
      @code_table,
      {code,
       %{
         user_id: user_id,
         client_id: client_id,
         redirect_uri: redirect_uri,
         code_challenge: code_challenge,
         expires_at: expires_at
       }}
    )

    code
  end

  def exchange_code(code, client_id, redirect_uri, code_verifier) do
    init()

    case :ets.take(@code_table, code) do
      [{^code, entry}] ->
        cond do
          entry.expires_at < System.monotonic_time(:millisecond) ->
            {:error, :expired}

          entry.client_id != client_id ->
            {:error, :invalid_client}

          entry.redirect_uri != redirect_uri ->
            {:error, :invalid_redirect_uri}

          not verify_pkce(code_verifier, entry.code_challenge) ->
            {:error, :invalid_code_verifier}

          true ->
            {:ok, entry.user_id}
        end

      [] ->
        {:error, :invalid_code}
    end
  end

  defp verify_pkce(nil, nil), do: true

  defp verify_pkce(verifier, challenge) when is_binary(verifier) and is_binary(challenge) do
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    computed == challenge
  end

  defp verify_pkce(_, _), do: false

  defp random_token(bytes) do
    :crypto.strong_rand_bytes(bytes) |> Base.url_encode64(padding: false)
  end
end
