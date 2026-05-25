defmodule RankTracker.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :auth0_subject, :string
    field :email, :string
    field :name, :string
    field :api_token, :string

    has_many :domains, RankTracker.Tracking.Domain

    timestamps(type: :utc_datetime)
  end

  def creation_changeset(user, attrs) do
    user
    |> cast(attrs, [:auth0_subject, :email, :name])
    |> validate_required([:auth0_subject, :email])
    |> unique_constraint(:auth0_subject)
    |> unique_constraint(:email)
    |> put_api_token()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end

  defp put_api_token(changeset) do
    if get_change(changeset, :auth0_subject) do
      token =
        :crypto.strong_rand_bytes(32)
        |> Base.url_encode64(padding: false)

      put_change(changeset, :api_token, token)
    else
      changeset
    end
  end
end
