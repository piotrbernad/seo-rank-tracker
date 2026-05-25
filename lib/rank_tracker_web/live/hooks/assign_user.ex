defmodule RankTrackerWeb.Live.Hooks.AssignUser do
  import Phoenix.LiveView
  import Phoenix.Component
  alias RankTracker.Accounts
  alias RankTracker.Billing

  def on_mount(:default, _params, session, socket) do
    auth_subject = session["auth_subject"]

    user =
      case auth_subject do
        %{"sub" => sub} when is_binary(sub) -> Accounts.get_by_subject(sub)
        _ -> nil
      end

    if user do
      {:ok, wallet} = Billing.get_or_create_wallet(user.id)

      {:cont,
       assign(socket,
         current_user: user,
         auth_subject: auth_subject,
         wallet_balance: wallet.balance
       )}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
