defmodule RankTracker.Tracking.Keyword do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "keywords" do
    field :text, :string

    belongs_to :domain, RankTracker.Tracking.Domain
    has_many :tracked_combinations, RankTracker.Tracking.TrackedCombination

    timestamps(type: :utc_datetime)
  end

  def changeset(keyword, attrs) do
    keyword
    |> cast(attrs, [:text, :domain_id])
    |> validate_required([:text, :domain_id])
    |> update_change(:text, &String.trim/1)
    |> update_change(:text, &String.downcase/1)
    |> validate_length(:text, min: 1, max: 500)
    |> unique_constraint([:domain_id, :text])
  end
end
