defmodule RankTracker.Billing do
  require Logger
  import Ecto.Query
  alias RankTracker.Repo
  alias RankTracker.Billing.{Wallet, Transaction}

  @margin Decimal.new("1.20")
  @dataforseo_cost Decimal.new("0.002")
  @stripe_percent Decimal.new("0.029")
  @stripe_fixed Decimal.new("0.30")

  def price_per_check do
    Decimal.mult(@dataforseo_cost, @margin)
  end

  def estimate_cost(count) when is_integer(count) do
    Decimal.mult(price_per_check(), count)
  end

  def calculate_stripe_fee(gross) do
    Decimal.add(Decimal.mult(gross, @stripe_percent), @stripe_fixed)
  end

  def calculate_net_after_stripe(gross) do
    Decimal.sub(gross, calculate_stripe_fee(gross))
  end

  # Wallet

  def get_wallet(user_id) do
    Repo.get_by(Wallet, user_id: user_id)
  end

  def get_or_create_wallet(user_id) do
    case get_wallet(user_id) do
      nil ->
        %Wallet{}
        |> Wallet.changeset(%{user_id: user_id})
        |> Repo.insert()

      wallet ->
        {:ok, wallet}
    end
  end

  def get_balance(user_id) do
    case get_wallet(user_id) do
      nil -> Decimal.new(0)
      wallet -> wallet.balance
    end
  end

  def sufficient_funds?(user_id, count) do
    balance = get_balance(user_id)
    needed = estimate_cost(count)
    Decimal.compare(balance, needed) in [:gt, :eq]
  end

  def update_auto_reload(wallet, attrs) do
    wallet
    |> Wallet.auto_reload_changeset(attrs)
    |> Repo.update()
  end

  # Debit

  def debit_for_rank_check(user_id, check_info) do
    amount = price_per_check()

    Repo.transaction(fn ->
      wallet =
        Wallet
        |> where(user_id: ^user_id)
        |> lock("FOR UPDATE")
        |> Repo.one!()

      if Decimal.compare(wallet.balance, amount) in [:gt, :eq] do
        new_balance = Decimal.sub(wallet.balance, amount)

        wallet
        |> Ecto.Changeset.change(balance: new_balance)
        |> Repo.update!()

        description =
          "#{check_info.keyword} | #{check_info.country} | #{check_info.domain}"

        %Transaction{}
        |> Transaction.changeset(%{
          wallet_id: wallet.id,
          type: "debit",
          amount: amount,
          balance_after: new_balance,
          description: description,
          metadata: %{
            "combination_id" => check_info.combination_id,
            "keyword" => check_info.keyword,
            "country" => check_info.country,
            "domain" => check_info.domain,
            "dataforseo_cost" => Decimal.to_string(@dataforseo_cost),
            "our_price" => Decimal.to_string(amount)
          }
        })
        |> Repo.insert!()
      else
        Repo.rollback(:insufficient_funds)
      end
    end)
  end

  def update_transaction_with_result(transaction_id, result_data) do
    Transaction
    |> Repo.get!(transaction_id)
    |> Ecto.Changeset.change(
      metadata:
        Map.merge(
          Repo.get!(Transaction, transaction_id).metadata,
          result_data
        )
    )
    |> Repo.update()
  end

  def refund_debit(user_id, check_info) do
    amount = price_per_check()

    Repo.transaction(fn ->
      wallet =
        Wallet
        |> where(user_id: ^user_id)
        |> lock("FOR UPDATE")
        |> Repo.one!()

      new_balance = Decimal.add(wallet.balance, amount)

      wallet
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      description =
        "Refund: #{check_info.keyword} | #{check_info.country} | #{check_info.domain}"

      %Transaction{}
      |> Transaction.changeset(%{
        wallet_id: wallet.id,
        type: "credit",
        amount: amount,
        balance_after: new_balance,
        description: description,
        metadata: %{
          "combination_id" => check_info.combination_id,
          "keyword" => check_info.keyword,
          "reason" => "api_call_failed"
        }
      })
      |> Repo.insert!()
    end)
  end

  # Credit

  def credit_from_stripe(wallet_id, amount, stripe_session_id) do
    existing =
      Transaction
      |> where(stripe_session_id: ^stripe_session_id)
      |> Repo.one()

    if existing do
      {:error, :already_processed}
    else
      Repo.transaction(fn ->
        wallet =
          Wallet
          |> where(id: ^wallet_id)
          |> lock("FOR UPDATE")
          |> Repo.one!()

        new_balance = Decimal.add(wallet.balance, amount)

        wallet
        |> Ecto.Changeset.change(balance: new_balance)
        |> Repo.update!()

        tx =
          %Transaction{}
          |> Transaction.changeset(%{
            wallet_id: wallet.id,
            type: "credit",
            amount: amount,
            balance_after: new_balance,
            description: "Funds loaded via Stripe",
            stripe_session_id: stripe_session_id
          })
          |> Repo.insert!()

        Phoenix.PubSub.broadcast(
          RankTracker.PubSub,
          "wallet:#{wallet.user_id}",
          {:wallet_updated, %{wallet | balance: new_balance}}
        )

        tx
      end)
    end
  end

  def credit_from_auto_reload(wallet_id, amount, stripe_payment_intent_id) do
    Repo.transaction(fn ->
      wallet =
        Wallet
        |> where(id: ^wallet_id)
        |> lock("FOR UPDATE")
        |> Repo.one!()

      new_balance = Decimal.add(wallet.balance, amount)

      wallet
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      %Transaction{}
      |> Transaction.changeset(%{
        wallet_id: wallet.id,
        type: "credit",
        amount: amount,
        balance_after: new_balance,
        description: "Auto-reload",
        stripe_payment_intent_id: stripe_payment_intent_id
      })
      |> Repo.insert!()
    end)
  end

  # Auto-reload trigger

  def maybe_trigger_auto_reload(%Wallet{auto_reload_enabled: false}), do: :ok

  def maybe_trigger_auto_reload(%Wallet{stripe_payment_method_id: nil}), do: :ok

  def maybe_trigger_auto_reload(%Wallet{} = wallet) do
    threshold = wallet.auto_reload_threshold || Decimal.new("1.00")

    if Decimal.compare(wallet.balance, threshold) == :lt do
      Task.Supervisor.start_child(RankTracker.TaskSupervisor, fn ->
        amount_dollars = wallet.auto_reload_amount || Decimal.new("10")
        amount_cents = Decimal.to_integer(Decimal.mult(amount_dollars, 100))

        case RankTracker.Billing.Stripe.charge_saved_method(wallet, amount_cents) do
          {:ok, _intent} ->
            :ok

          {:error, reason} ->
            Logger.error("Auto-reload failed: #{inspect(reason)}")
        end
      end)

      :ok
    else
      :ok
    end
  end

  # Transaction history

  def list_transactions(wallet_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Transaction
    |> where(wallet_id: ^wallet_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
