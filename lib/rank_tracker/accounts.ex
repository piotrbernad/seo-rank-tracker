defmodule RankTracker.Accounts do
  alias RankTracker.Repo
  alias RankTracker.Accounts.User

  def get(id), do: Repo.get(User, id)

  def get_by_subject(auth0_subject) do
    Repo.get_by(User, auth0_subject: auth0_subject)
  end

  def get_by_api_token(token) when is_binary(token) do
    Repo.get_by(User, api_token: token)
  end

  def get_by_api_token(_), do: nil

  def get_or_create_by_subject(subject, email, name \\ nil) do
    case get_by_subject(subject) do
      nil ->
        %User{}
        |> User.creation_changeset(%{auth0_subject: subject, email: email, name: name})
        |> Repo.insert()

      user ->
        user
        |> User.update_changeset(%{email: email, name: name})
        |> Repo.update()
    end
  end

  def regenerate_api_token(user) do
    token =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    user
    |> Ecto.Changeset.change(api_token: token)
    |> Repo.update()
  end
end
