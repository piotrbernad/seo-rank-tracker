defmodule RankTracker.Billing.Stripe do
  require Logger
  alias RankTracker.Billing
  alias RankTracker.Billing.Wallet
  alias RankTracker.Repo

  defp api_key, do: Application.get_env(:stripity_stripe, :api_key)

  defp stripe_request(method, path, params \\ %{}) do
    url = "https://api.stripe.com/v1#{path}"

    req =
      Req.new(
        method: method,
        url: url,
        headers: [
          {"Authorization", "Bearer #{api_key()}"},
          {"Content-Type", "application/x-www-form-urlencoded"}
        ],
        body: if(params != %{}, do: URI.encode_query(flatten_params(params)), else: ""),
        connect_options: [transport_opts: [cacertfile: CAStore.file_path()]],
        receive_timeout: 30_000
      )

    case Req.request(req) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp flatten_params(params, prefix \\ nil) do
    Enum.flat_map(params, fn {key, value} ->
      full_key = if prefix, do: "#{prefix}[#{key}]", else: to_string(key)

      cond do
        is_map(value) ->
          flatten_params(value, full_key)

        is_list(value) ->
          Enum.with_index(value)
          |> Enum.flat_map(fn {v, i} ->
            if is_map(v),
              do: flatten_params(v, "#{full_key}[#{i}]"),
              else: [{"#{full_key}[#{i}]", v}]
          end)

        true ->
          [{full_key, to_string(value)}]
      end
    end)
  end

  def create_checkout_session(%Wallet{} = wallet, amount_cents, success_url, cancel_url) do
    with {:ok, customer_id} <- ensure_customer(wallet) do
      params = %{
        "customer" => customer_id,
        "mode" => "payment",
        "payment_method_types[0]" => "card",
        "payment_intent_data[setup_future_usage]" => "off_session",
        "line_items[0][price_data][currency]" => "usd",
        "line_items[0][price_data][unit_amount]" => to_string(amount_cents),
        "line_items[0][price_data][product_data][name]" => "SEO Rank Tracker - Wallet Top-up",
        "line_items[0][quantity]" => "1",
        "metadata[wallet_id]" => wallet.id,
        "success_url" => success_url <> "?session_id={CHECKOUT_SESSION_ID}",
        "cancel_url" => cancel_url
      }

      req =
        Req.new(
          method: :post,
          url: "https://api.stripe.com/v1/checkout/sessions",
          headers: [
            {"Authorization", "Bearer #{api_key()}"},
            {"Content-Type", "application/x-www-form-urlencoded"}
          ],
          body: URI.encode_query(params),
          connect_options: [transport_opts: [cacertfile: CAStore.file_path()]],
          receive_timeout: 30_000
        )

      case Req.request(req) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, %{url: body["url"], id: body["id"]}}

        {:ok, %Req.Response{body: body}} ->
          {:error, body["error"]["message"] || "Stripe error"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def handle_checkout_completed(session) do
    wallet_id = get_in_any(session, "metadata", "wallet_id")
    amount_cents = get_in_any(session, "amount_total") || 0
    session_id = get_in_any(session, "id")

    gross = Decimal.div(Decimal.new(amount_cents), Decimal.new(100))
    net = Billing.calculate_net_after_stripe(gross)

    payment_intent_id = get_in_any(session, "payment_intent")

    if payment_intent_id do
      save_payment_method(wallet_id, payment_intent_id)
    end

    Billing.credit_from_stripe(wallet_id, net, session_id)
  end

  def charge_saved_method(%Wallet{} = wallet, amount_cents) do
    case stripe_request(:post, "/payment_intents", %{
           customer: wallet.stripe_customer_id,
           payment_method: wallet.stripe_payment_method_id,
           amount: amount_cents,
           currency: "usd",
           off_session: "true",
           confirm: "true"
         }) do
      {:ok, intent} ->
        gross = Decimal.div(Decimal.new(amount_cents), Decimal.new(100))
        net = Billing.calculate_net_after_stripe(gross)
        Billing.credit_from_auto_reload(wallet.id, net, intent["id"])
        {:ok, intent}

      {:error, error} ->
        Logger.error("Auto-reload charge failed: #{inspect(error)}")
        {:error, error}
    end
  end

  def verify_webhook(payload, signature) do
    secret = Application.get_env(:rank_tracker, :stripe_webhook_secret)

    if is_nil(secret) or secret == "" do
      case Jason.decode(payload) do
        {:ok, event} -> {:ok, event}
        error -> error
      end
    else
      Stripe.Webhook.construct_event(payload, signature, secret)
    end
  end

  defp ensure_customer(%Wallet{stripe_customer_id: id} = _wallet)
       when is_binary(id) and id != "" do
    {:ok, id}
  end

  defp ensure_customer(%Wallet{} = wallet) do
    wallet = Repo.preload(wallet, :user)

    case stripe_request(:post, "/customers", %{
           email: wallet.user.email,
           name: wallet.user.name || ""
         }) do
      {:ok, customer} ->
        wallet
        |> Ecto.Changeset.change(stripe_customer_id: customer["id"])
        |> Repo.update!()

        {:ok, customer["id"]}

      {:error, error} ->
        {:error, error}
    end
  end

  defp save_payment_method(wallet_id, payment_intent_id) do
    case stripe_request(:get, "/payment_intents/#{payment_intent_id}") do
      {:ok, %{"payment_method" => pm_id}} when is_binary(pm_id) ->
        Wallet
        |> Repo.get!(wallet_id)
        |> Ecto.Changeset.change(stripe_payment_method_id: pm_id)
        |> Repo.update()

      _ ->
        :ok
    end
  end

  defp get_in_any(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  end

  defp get_in_any(map, key1, key2) when is_map(map) do
    nested = get_in_any(map, key1)
    if is_map(nested), do: get_in_any(nested, key2), else: nil
  end
end
