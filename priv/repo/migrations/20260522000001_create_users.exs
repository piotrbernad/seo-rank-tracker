defmodule RankTracker.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :auth0_subject, :string, null: false
      add :email, :string, null: false
      add :name, :string
      add :api_token, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:auth0_subject])
    create unique_index(:users, [:email])
    create unique_index(:users, [:api_token])
  end
end
