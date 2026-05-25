defmodule RankTracker.Tracking.RankResult do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rank_results" do
    field :position, :integer
    field :url, :string
    field :domain, :string
    field :title, :string
    field :cost, :decimal
    field :checked_at, :utc_datetime
    field :raw_response, :map

    belongs_to :tracked_combination, RankTracker.Tracking.TrackedCombination

    timestamps(type: :utc_datetime)
  end

  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :position,
      :url,
      :domain,
      :title,
      :cost,
      :checked_at,
      :raw_response,
      :tracked_combination_id
    ])
    |> validate_required([:cost, :checked_at, :tracked_combination_id])
  end
end
