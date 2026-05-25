defmodule RankTrackerWeb.StripeController do
  use RankTrackerWeb, :controller

  alias RankTracker.Billing.Stripe, as: BillingStripe

  def webhook(conn, _params) do
    payload = conn.private[:raw_body] || ""
    signature = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first("")

    case BillingStripe.verify_webhook(payload, signature) do
      {:ok, %{type: "checkout.session.completed", data: %{object: session}}} ->
        BillingStripe.handle_checkout_completed(session)
        json(conn, %{status: "ok"})

      {:ok, _event} ->
        json(conn, %{status: "ok"})

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: inspect(reason)})
    end
  end
end
