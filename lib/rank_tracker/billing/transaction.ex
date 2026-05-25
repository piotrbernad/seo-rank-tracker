defmodule RankTracker.Billing.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wallet_transactions" do
    field :type, :string
    field :amount, :decimal
    field :balance_after, :decimal
    field :description, :string
    field :stripe_session_id, :string
    field :stripe_payment_intent_id, :string
    field :metadata, :map, default: %{}

    belongs_to :wallet, RankTracker.Billing.Wallet

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :type,
      :amount,
      :balance_after,
      :description,
      :stripe_session_id,
      :stripe_payment_intent_id,
      :metadata,
      :wallet_id
    ])
    |> validate_required([:type, :amount, :balance_after, :description, :wallet_id])
    |> validate_inclusion(:type, ~w(credit debit))
    |> validate_number(:amount, greater_than: 0)
  end
end
