defmodule RankTrackerWeb.AuthController do
  use RankTrackerWeb, :controller

  alias RankTracker.Auth
  alias RankTracker.Accounts

  @pkce_bytes 64

  def login(conn, _params) do
    state = generate_random_token()
    code_verifier = generate_pkce_verifier()
    code_challenge = generate_pkce_challenge(code_verifier)

    conn
    |> put_session(:oauth_state, state)
    |> put_session(:code_verifier, code_verifier)
    |> redirect(external: Auth.authorization_url(state, code_challenge))
  end

  def callback(%Plug.Conn{params: %{"error" => error}} = conn, _params) do
    handle_auth_error(conn, "Authentication failed: #{error}")
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    with {:ok, :state_verified} <- verify_oauth_state(conn, state),
         {:ok, tokens} <- exchange_auth_code(conn, code),
         {:ok, userinfo} <- fetch_userinfo(tokens),
         {:ok, claims} <- extract_claims(tokens),
         {:ok, user_data} <- build_user_data(claims, userinfo),
         {:ok, _db_user} <-
           Accounts.get_or_create_by_subject(
             user_data.subject,
             user_data.email,
             user_data.name
           ) do
      handle_successful_auth(conn, user_data)
    else
      {:error, reason} ->
        handle_auth_error(conn, "Authentication failed: #{inspect(reason)}")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> redirect(to: ~p"/")
  end

  def dev_login(conn, _params) do
    {:ok, user} =
      Accounts.get_or_create_by_subject(
        "dev|local-test-user",
        "dev@localhost",
        "Dev User"
      )

    auth_subject = %{
      "sub" => user.auth0_subject,
      "email" => user.email,
      "name" => user.name
    }

    conn
    |> configure_session(renew: true)
    |> put_session(:auth_subject, auth_subject)
    |> put_flash(:info, "Logged in as dev user")
    |> redirect(to: ~p"/dashboard")
  end

  defp verify_oauth_state(conn, returned_state) do
    case get_session(conn, :oauth_state) do
      ^returned_state -> {:ok, :state_verified}
      _ -> {:error, :state_mismatch}
    end
  end

  defp exchange_auth_code(conn, code) do
    code_verifier = get_session(conn, :code_verifier) || ""
    Auth.exchange_code(code, code_verifier, Auth.config().redirect_uri)
  end

  defp fetch_userinfo(%{"access_token" => token}), do: Auth.userinfo(token)
  defp fetch_userinfo(_), do: {:ok, %{}}

  defp extract_claims(%{"id_token" => id_token}) when is_binary(id_token) do
    case decode_jwt_claims(id_token) do
      claims when is_map(claims) and map_size(claims) > 0 -> {:ok, claims}
      _ -> {:error, :invalid_token}
    end
  end

  defp extract_claims(%{"id_token_claims" => claims}) when is_map(claims), do: {:ok, claims}
  defp extract_claims(_), do: {:error, :missing_claims}

  defp decode_jwt_claims(id_token) do
    with [_, payload_segment | _] <- String.split(id_token, "."),
         {:ok, payload} <- Base.url_decode64(payload_segment, padding: false),
         {:ok, claims} <- Jason.decode(payload) do
      claims
    else
      _ -> %{}
    end
  end

  defp build_user_data(claims, userinfo) do
    subject = userinfo["sub"] || claims["sub"]
    email = userinfo["email"] || claims["email"]
    name = userinfo["name"] || claims["name"]

    cond do
      is_nil(subject) or subject == "" -> {:error, :missing_subject}
      is_nil(email) or email == "" -> {:error, :email_required}
      true -> {:ok, %{subject: subject, email: email, name: name}}
    end
  end

  defp handle_successful_auth(conn, user_data) do
    greeting = user_data.name || user_data.email || "there"

    auth_subject = %{
      "sub" => user_data.subject,
      "email" => user_data.email,
      "name" => user_data.name
    }

    return_to = get_session(conn, :oauth_return_to)

    conn
    |> configure_session(renew: true)
    |> put_session(:auth_subject, auth_subject)
    |> delete_session(:oauth_state)
    |> delete_session(:code_verifier)
    |> delete_session(:oauth_return_to)
    |> put_flash(:info, "Welcome back, #{greeting}!")
    |> redirect(to: return_to || ~p"/dashboard")
  end

  defp handle_auth_error(conn, message) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_flash(:error, message)
    |> redirect(to: ~p"/")
  end

  defp generate_random_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp generate_pkce_verifier do
    :crypto.strong_rand_bytes(@pkce_bytes) |> Base.url_encode64(padding: false)
  end

  defp generate_pkce_challenge(verifier) do
    :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
  end
end
