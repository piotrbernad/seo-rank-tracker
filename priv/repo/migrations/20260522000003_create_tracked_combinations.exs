defmodule RankTracker.Repo.Migrations.CreateTrackedCombinations do
  use Ecto.Migration

  def change do
    create table(:tracked_combinations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country_code, :integer, null: false

      add :keyword_id, references(:keywords, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tracked_combinations, [:keyword_id])
    create unique_index(:tracked_combinations, [:keyword_id, :country_code])
  end
end
