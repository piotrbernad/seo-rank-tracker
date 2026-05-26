defmodule RankTrackerWeb.BillingLive do
  use RankTrackerWeb, :live_view

  alias RankTracker.Billing

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    {:ok, wallet} = Billing.get_or_create_wallet(user_id)
    transactions = Billing.list_transactions(wallet.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(RankTracker.PubSub, "wallet:#{user_id}")
    end

    {:ok,
     assign(socket,
       page_title: "Billing",
       wallet: wallet,
       transactions: transactions,
       load_amount: "10",
       auto_reload_form: to_form(Billing.Wallet.auto_reload_changeset(wallet, %{}))
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-12">
        <span class="section-label">Billing</span>
        <h1 class="text-2xl font-light text-[oklch(8%_0.005_260)] mt-1">Wallet</h1>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-12">
        <%!-- Balance --%>
        <div class="border border-[oklch(88%_0.005_260)] p-6">
          <span class="section-label">Current Balance</span>
          <div class="font-mono text-4xl font-bold text-[oklch(8%_0.005_260)] mt-2">
            ${Decimal.round(@wallet.balance, 2)}
          </div>
          <p class="font-mono text-xs text-[oklch(55%_0.005_260)] mt-2">
            ~{checks_remaining(@wallet.balance)} rank checks remaining
          </p>
          <p class="font-mono text-xs text-[oklch(55%_0.005_260)] mt-1">
            Cost per check: ${Decimal.round(Billing.price_per_check(), 4)}
          </p>
        </div>

        <%!-- Load Funds --%>
        <div class="border border-[oklch(88%_0.005_260)] p-6">
          <span class="section-label">Add Funds</span>
          <form phx-submit="load_funds" class="mt-3">
            <div class="flex gap-3 items-end">
              <div class="flex-1">
                <label class="font-mono text-xs text-[oklch(50%_0.005_260)] uppercase tracking-wider block mb-1">
                  Amount (USD)
                </label>
                <input
                  type="number"
                  name="amount"
                  value={@load_amount}
                  min="5"
                  step="1"
                  class="input-field w-full"
                  phx-change="update_load_amount"
                />
              </div>
              <button type="submit" class="btn-action btn-action-primary">
                Add Funds
              </button>
            </div>
            <div class="mt-3 font-mono text-xs text-[oklch(50%_0.005_260)] space-y-0.5">
              <div>You pay: ${@load_amount}</div>
              <div>Processing fee: ${format_fee(@load_amount)}</div>
              <div class="text-[oklch(25%_0.005_260)]">
                Credited: ${format_net(@load_amount)}
              </div>
            </div>
          </form>
        </div>
      </div>

      <%!-- Auto-Reload --%>
      <div class="border border-[oklch(88%_0.005_260)] p-6 mb-12">
        <span class="section-label">Auto-Reload</span>
        <p class="text-sm text-[oklch(50%_0.005_260)] mt-1 mb-4">
          Automatically reload your wallet when balance drops below the threshold.
          <%= if is_nil(@wallet.stripe_payment_method_id) do %>
            <span class="text-[oklch(50%_0.2_25)]">
              Add funds at least once to save a payment method.
            </span>
          <% end %>
        </p>
        <.form
          for={@auto_reload_form}
          phx-submit="save_auto_reload"
          class="flex flex-wrap gap-4 items-end"
        >
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              name={@auto_reload_form[:auto_reload_enabled].name}
              value="true"
              checked={@auto_reload_form[:auto_reload_enabled].value == true}
              class="w-4 h-4"
            />
            <span class="font-mono text-xs uppercase tracking-wider">Enabled</span>
          </label>
          <div>
            <label class="font-mono text-xs text-[oklch(50%_0.005_260)] uppercase tracking-wider block mb-1">
              Reload Amount
            </label>
            <input
              type="number"
              name={@auto_reload_form[:auto_reload_amount].name}
              value={@auto_reload_form[:auto_reload_amount].value || "10"}
              min="5"
              step="1"
              class="input-field w-28"
            />
          </div>
          <div>
            <label class="font-mono text-xs text-[oklch(50%_0.005_260)] uppercase tracking-wider block mb-1">
              When below
            </label>
            <input
              type="number"
              name={@auto_reload_form[:auto_reload_threshold].name}
              value={@auto_reload_form[:auto_reload_threshold].value || "1"}
              min="0.5"
              step="0.5"
              class="input-field w-28"
            />
          </div>
          <button
            type="submit"
            class="btn-action"
            disabled={is_nil(@wallet.stripe_payment_method_id)}
          >
            Save
          </button>
        </.form>
      </div>

      <%!-- Transaction History --%>
      <div>
        <span class="section-label">Transaction History</span>
        <%= if @transactions == [] do %>
          <div class="py-12 text-center mt-4">
            <p class="font-mono text-xs text-[oklch(55%_0.005_260)]">
              [ No transactions yet ]
            </p>
          </div>
        <% else %>
          <table class="data-table mt-4">
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Amount</th>
                <th>Balance</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              <%= for tx <- @transactions do %>
                <tr>
                  <td class="font-mono text-xs text-[oklch(55%_0.005_260)]">
                    {format_time(tx.inserted_at, @timezone)}
                  </td>
                  <td>
                    <span class={
                      "font-mono text-xs font-medium " <>
                        if(tx.type == "credit",
                          do: "text-[oklch(42%_0.16_155)]",
                          else: "text-[oklch(50%_0.005_260)]"
                        )
                    }>
                      {tx.type}
                    </span>
                  </td>
                  <td class="font-mono text-sm">
                    <span class={
                      if(tx.type == "credit",
                        do: "text-[oklch(42%_0.16_155)]",
                        else: "text-[oklch(25%_0.005_260)]"
                      )
                    }>
                      {if(tx.type == "credit", do: "+", else: "-")}${Decimal.round(tx.amount, 4)}
                    </span>
                  </td>
                  <td class="font-mono text-xs text-[oklch(50%_0.005_260)]">
                    ${Decimal.round(tx.balance_after, 4)}
                  </td>
                  <td class="text-sm text-[oklch(40%_0.005_260)]">{tx.description}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("update_load_amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, load_amount: amount)}
  end

  def handle_event("load_funds", %{"amount" => amount_str}, socket) do
    amount = String.to_integer(amount_str)
    amount_cents = amount * 100
    wallet = socket.assigns.wallet

    success_url = RankTrackerWeb.Endpoint.url() <> "/billing"
    cancel_url = RankTrackerWeb.Endpoint.url() <> "/billing"

    case RankTracker.Billing.Stripe.create_checkout_session(
           wallet,
           amount_cents,
           success_url,
           cancel_url
         ) do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Payment error: #{inspect(error)}")}
    end
  end

  def handle_event("save_auto_reload", params, socket) do
    attrs = %{
      auto_reload_enabled: params["auto_reload_enabled"] == "true",
      auto_reload_amount: params["auto_reload_amount"],
      auto_reload_threshold: params["auto_reload_threshold"]
    }

    case Billing.update_auto_reload(socket.assigns.wallet, attrs) do
      {:ok, wallet} ->
        {:noreply,
         socket
         |> assign(
           wallet: wallet,
           auto_reload_form: to_form(Billing.Wallet.auto_reload_changeset(wallet, %{}))
         )
         |> put_flash(:info, "Auto-reload settings saved")}

      {:error, changeset} ->
        {:noreply, assign(socket, auto_reload_form: to_form(changeset))}
    end
  end

  def handle_info({:wallet_updated, wallet}, socket) do
    transactions = Billing.list_transactions(wallet.id)

    {:noreply,
     assign(socket,
       wallet: wallet,
       transactions: transactions
     )}
  end

  defp checks_remaining(balance) do
    price = Billing.price_per_check()

    if Decimal.compare(price, 0) == :gt do
      Decimal.div_int(balance, price) |> Decimal.to_integer()
    else
      0
    end
  end

  defp format_fee(amount_str) do
    case Integer.parse(amount_str) do
      {n, _} when n > 0 ->
        Billing.calculate_stripe_fee(Decimal.new(n)) |> Decimal.round(2) |> Decimal.to_string()

      _ ->
        "0.00"
    end
  end

  defp format_net(amount_str) do
    case Integer.parse(amount_str) do
      {n, _} when n > 0 ->
        Billing.calculate_net_after_stripe(Decimal.new(n))
        |> Decimal.round(2)
        |> Decimal.to_string()

      _ ->
        "0.00"
    end
  end
end
