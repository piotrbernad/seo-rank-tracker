defmodule RankTracker.Tracking do
  import Ecto.Query
  alias RankTracker.Repo
  alias RankTracker.Tracking.{Domain, Keyword, TrackedCombination, RankResult}

  # Domains

  def list_domains(user_id) do
    Domain
    |> where(user_id: ^user_id)
    |> order_by(:domain)
    |> Repo.all()
  end

  def get_domain!(id), do: Repo.get!(Domain, id)

  def get_user_domain!(user_id, domain_id) do
    Domain
    |> where(id: ^domain_id, user_id: ^user_id)
    |> Repo.one!()
  end

  def create_domain(user_id, domain_name) do
    %Domain{}
    |> Domain.changeset(%{domain: domain_name, user_id: user_id})
    |> Repo.insert()
  end

  def delete_domain(user_id, domain_id) do
    Domain
    |> where(id: ^domain_id, user_id: ^user_id)
    |> Repo.delete_all()
  end

  # Keywords

  def list_keywords(domain_id) do
    Keyword
    |> where(domain_id: ^domain_id)
    |> order_by(:text)
    |> Repo.all()
  end

  def create_keywords(domain_id, texts) when is_list(texts) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      texts
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.map(fn text ->
        %{
          id: Ecto.UUID.generate(),
          text: text,
          domain_id: domain_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Keyword, entries, on_conflict: :nothing, returning: true)
  end

  def delete_keyword(keyword_id) do
    Keyword
    |> where(id: ^keyword_id)
    |> Repo.delete_all()
  end

  # Combinations

  def list_combinations_by_user(user_id) do
    latest_results =
      from(r in RankResult,
        distinct: r.tracked_combination_id,
        order_by: [desc: r.checked_at]
      )

    query =
      from(tc in TrackedCombination,
        join: k in assoc(tc, :keyword),
        join: d in assoc(k, :domain),
        where: d.user_id == ^user_id,
        preload: [keyword: {k, domain: d}, rank_results: ^latest_results]
      )

    Repo.all(query)
    |> Enum.sort_by(fn combo ->
      pos =
        case List.first(combo.rank_results) do
          nil -> 999
          r -> r.position || 999
        end

      {combo.keyword.domain.domain, pos, combo.keyword.text}
    end)
  end

  def list_combinations(domain_id) do
    latest_results =
      from(r in RankResult,
        distinct: r.tracked_combination_id,
        order_by: [desc: r.checked_at]
      )

    query =
      from(tc in TrackedCombination,
        join: k in assoc(tc, :keyword),
        where: k.domain_id == ^domain_id,
        preload: [keyword: k, rank_results: ^latest_results],
        order_by: [asc: k.text, asc: tc.country_code]
      )

    Repo.all(query)
  end

  def get_combination!(id) do
    TrackedCombination
    |> Repo.get!(id)
    |> Repo.preload(keyword: :domain)
  end

  def create_combinations_for_keywords(keyword_ids, country_codes) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      for keyword_id <- keyword_ids, code <- country_codes do
        %{
          id: Ecto.UUID.generate(),
          keyword_id: keyword_id,
          country_code: code,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(TrackedCombination, entries, on_conflict: :nothing, returning: true)
  end

  def delete_combination(combination_id) do
    TrackedCombination
    |> where(id: ^combination_id)
    |> Repo.delete_all()
  end

  # Results

  def list_results(combination_id, opts \\ []) do
    limit = Elixir.Keyword.get(opts, :limit, 50)

    RankResult
    |> where(tracked_combination_id: ^combination_id)
    |> order_by(desc: :checked_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def create_result(attrs) do
    %RankResult{}
    |> RankResult.changeset(attrs)
    |> Repo.insert()
  end
end
