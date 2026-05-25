defmodule RankTracker.Repo.Migrations.CreateKeywords do
  use Ecto.Migration

  def change do
    create table(:keywords, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:keywords, [:user_id])
    create unique_index(:keywords, [:user_id, :text])
  end
end
