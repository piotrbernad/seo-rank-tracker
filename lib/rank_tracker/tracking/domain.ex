defmodule RankTracker.Tracking.Domain do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "domains" do
    field :domain, :string

    belongs_to :user, RankTracker.Accounts.User
    has_many :keywords, RankTracker.Tracking.Keyword

    timestamps(type: :utc_datetime)
  end

  def changeset(domain, attrs) do
    domain
    |> cast(attrs, [:domain, :user_id])
    |> validate_required([:domain, :user_id])
    |> update_change(:domain, &normalize/1)
    |> validate_format(:domain, ~r/^[a-z0-9][a-z0-9\-\.]*\.[a-z]{2,}$/,
      message: "must be a valid domain (e.g. example.com)"
    )
    |> unique_constraint([:user_id, :domain])
  end

  defp normalize(domain) do
    domain
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r{^https?://}, "")
    |> String.replace(~r{/.*$}, "")
    |> String.replace(~r{^www\.}, "")
  end
end
