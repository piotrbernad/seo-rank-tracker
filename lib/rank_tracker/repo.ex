defmodule RankTracker.Repo do
  use Ecto.Repo,
    otp_app: :rank_tracker,
    adapter: Ecto.Adapters.Postgres
end
