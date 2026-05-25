defmodule RankTracker.Billing.Stripe do
  require Logger
  alias RankTracker.Billing
  alias RankTracker.Billing.Wallet
  alias RankTracker.Repo

  def create_checkout_session(%Wallet{} = wallet, amount_cents, success_url, cancel_url) do
    with {:ok, customer_id} <- ensure_customer(wallet) do
      params = %{
        customer: customer_id,
        mode: "payment",
        payment_method_types: ["card"],
        line_items: [
          %{
            price_data: %{
              currency: "usd",
              unit_amount: amount_cents,
              product_data: %{name: "SEO Rank Tracker - Wallet Top-up"}
            },
            quantity: 1
          }
        ],
        payment_intent_data: %{
          setup_future_usage: "off_session"
        },
        metadata: %{"wallet_id" => wallet.id},
        success_url: success_url <> "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancel_url
      }

      Stripe.Checkout.Session.create(params)
    end
  end

  def handle_checkout_completed(session) do
    wallet_id = session["metadata"]["wallet_id"] || session.metadata["wallet_id"]
    amount_cents = session["amount_total"] || session.amount_total
    session_id = session["id"] || session.id

    gross = Decimal.div(Decimal.new(amount_cents), Decimal.new(100))
    net = Billing.calculate_net_after_stripe(gross)

    payment_intent_id =
      session["payment_intent"] || Map.get(session, :payment_intent)

    if payment_intent_id do
      save_payment_method(wallet_id, payment_intent_id)
    end

    Billing.credit_from_stripe(wallet_id, net, session_id)
  end

  def charge_saved_method(%Wallet{} = wallet, amount_cents) do
    params = %{
      customer: wallet.stripe_customer_id,
      payment_method: wallet.stripe_payment_method_id,
      amount: amount_cents,
      currency: "usd",
      off_session: true,
      confirm: true
    }

    case Stripe.PaymentIntent.create(params) do
      {:ok, intent} ->
        gross = Decimal.div(Decimal.new(amount_cents), Decimal.new(100))
        net = Billing.calculate_net_after_stripe(gross)
        Billing.credit_from_auto_reload(wallet.id, net, intent.id)
        {:ok, intent}

      {:error, error} ->
        Logger.error("Auto-reload charge failed: #{inspect(error)}")
        {:error, error}
    end
  end

  def verify_webhook(payload, signature) do
    secret = Application.get_env(:rank_tracker, :stripe_webhook_secret)
    Stripe.Webhook.construct_event(payload, signature, secret)
  end

  defp ensure_customer(%Wallet{stripe_customer_id: id}) when is_binary(id) do
    {:ok, id}
  end

  defp ensure_customer(%Wallet{} = wallet) do
    wallet = Repo.preload(wallet, :user)

    case Stripe.Customer.create(%{email: wallet.user.email, name: wallet.user.name}) do
      {:ok, customer} ->
        wallet
        |> Ecto.Changeset.change(stripe_customer_id: customer.id)
        |> Repo.update!()

        {:ok, customer.id}

      {:error, error} ->
        {:error, error}
    end
  end

  defp save_payment_method(wallet_id, payment_intent_id) do
    case Stripe.PaymentIntent.retrieve(payment_intent_id) do
      {:ok, %{payment_method: pm_id}} when is_binary(pm_id) ->
        Wallet
        |> Repo.get!(wallet_id)
        |> Ecto.Changeset.change(stripe_payment_method_id: pm_id)
        |> Repo.update()

      _ ->
        :ok
    end
  end
end
