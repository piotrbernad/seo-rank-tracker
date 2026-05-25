defmodule RankTracker.Billing.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wallets" do
    field :balance, :decimal, default: Decimal.new(0)
    field :auto_reload_enabled, :boolean, default: false
    field :auto_reload_amount, :decimal
    field :auto_reload_threshold, :decimal, default: Decimal.new("1.00")
    field :stripe_customer_id, :string
    field :stripe_payment_method_id, :string

    belongs_to :user, RankTracker.Accounts.User
    has_many :transactions, RankTracker.Billing.Transaction

    timestamps(type: :utc_datetime)
  end

  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [
      :balance,
      :auto_reload_enabled,
      :auto_reload_amount,
      :auto_reload_threshold,
      :stripe_customer_id,
      :stripe_payment_method_id,
      :user_id
    ])
    |> validate_required([:user_id])
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> unique_constraint(:user_id)
  end

  def auto_reload_changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:auto_reload_enabled, :auto_reload_amount, :auto_reload_threshold])
    |> validate_required([:auto_reload_enabled])
    |> maybe_validate_auto_reload()
  end

  defp maybe_validate_auto_reload(changeset) do
    if get_field(changeset, :auto_reload_enabled) do
      changeset
      |> validate_required([:auto_reload_amount, :auto_reload_threshold])
      |> validate_number(:auto_reload_amount, greater_than_or_equal_to: 5)
      |> validate_number(:auto_reload_threshold, greater_than: 0)
    else
      changeset
    end
  end
end
