defmodule RankTrackerWeb.Plugs.FetchCurrentUser do
  import Plug.Conn
  alias RankTracker.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    auth_subject = get_session(conn, :auth_subject)

    user =
      case auth_subject do
        %{"sub" => sub} when is_binary(sub) -> Accounts.get_by_subject(sub)
        _ -> nil
      end

    conn
    |> assign(:auth_subject, auth_subject)
    |> assign(:current_user, user)
  end
end
