defmodule RankTracker.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :balance, :decimal, precision: 12, scale: 6, null: false, default: 0
      add :auto_reload_enabled, :boolean, null: false, default: false
      add :auto_reload_amount, :decimal, precision: 10, scale: 2
      add :auto_reload_threshold, :decimal, precision: 10, scale: 2, default: "1.00"
      add :stripe_customer_id, :string
      add :stripe_payment_method_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wallets, [:user_id])
    create index(:wallets, [:stripe_customer_id])
  end
end
