defmodule RankTracker.Repo.Migrations.CreateRankResults do
  use Ecto.Migration

  def change do
    create table(:rank_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer
      add :url, :string
      add :domain, :string
      add :title, :string
      add :cost, :decimal, precision: 10, scale: 6, null: false
      add :checked_at, :utc_datetime, null: false
      add :raw_response, :map

      add :tracked_combination_id,
          references(:tracked_combinations, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rank_results, [:tracked_combination_id])
    create index(:rank_results, [:checked_at])
  end
end
