defmodule RankTracker.Repo.Migrations.CreateDomainsAndRestructure do
  use Ecto.Migration

  def change do
    create table(:domains, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:domains, [:user_id])
    create unique_index(:domains, [:user_id, :domain])

    alter table(:keywords) do
      add :domain_id, references(:domains, type: :binary_id, on_delete: :delete_all)
    end

    create index(:keywords, [:domain_id])

    # Move existing keywords: we can't auto-migrate since there's no domain yet,
    # but the data from dev testing can be recreated
    execute("DELETE FROM rank_results", "SELECT 1")
    execute("DELETE FROM tracked_combinations", "SELECT 1")
    execute("DELETE FROM keywords", "SELECT 1")

    alter table(:keywords) do
      remove :user_id
    end

    drop_if_exists unique_index(:keywords, [:user_id, :text])
    create unique_index(:keywords, [:domain_id, :text])

    alter table(:users) do
      remove :target_domain, :string
    end
  end
end
