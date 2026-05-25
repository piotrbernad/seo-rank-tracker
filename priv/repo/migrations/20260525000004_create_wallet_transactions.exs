defmodule RankTracker.Repo.Migrations.CreateWalletTransactions do
  use Ecto.Migration

  def change do
    create table(:wallet_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :wallet_id, references(:wallets, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :amount, :decimal, precision: 12, scale: 6, null: false
      add :balance_after, :decimal, precision: 12, scale: 6, null: false
      add :description, :string, null: false
      add :stripe_session_id, :string
      add :stripe_payment_intent_id, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:wallet_transactions, [:wallet_id])
    create index(:wallet_transactions, [:stripe_session_id])
    create index(:wallet_transactions, [:inserted_at])
  end
end
