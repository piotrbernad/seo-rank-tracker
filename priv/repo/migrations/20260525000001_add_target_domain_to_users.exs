defmodule RankTracker.Repo.Migrations.AddTargetDomainToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :target_domain, :string
    end
  end
end
