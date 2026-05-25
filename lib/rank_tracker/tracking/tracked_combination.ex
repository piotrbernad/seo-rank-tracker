defmodule RankTracker.Tracking.TrackedCombination do
  use Ecto.Schema
  import Ecto.Changeset

  alias RankTracker.DataForSeo.Locations

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tracked_combinations" do
    field :country_code, :integer

    belongs_to :keyword, RankTracker.Tracking.Keyword
    has_many :rank_results, RankTracker.Tracking.RankResult

    timestamps(type: :utc_datetime)
  end

  def changeset(combination, attrs) do
    combination
    |> cast(attrs, [:country_code, :keyword_id])
    |> validate_required([:country_code, :keyword_id])
    |> validate_change(:country_code, fn :country_code, code ->
      if Locations.valid_location_code?(code),
        do: [],
        else: [country_code: "invalid location code"]
    end)
    |> unique_constraint([:keyword_id, :country_code])
  end
end
