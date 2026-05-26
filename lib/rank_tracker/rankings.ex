defmodule RankTracker.Rankings do
  alias RankTracker.Repo
  alias RankTracker.Tracking
  alias RankTracker.Tracking.TrackedCombination
  alias RankTracker.DataForSeo.{Client, Locations}

  @cost_per_check Decimal.new("0.002")

  def cost_per_check, do: @cost_per_check

  def estimate_cost(count) when is_integer(count) do
    %{count: count, cost: Decimal.mult(@cost_per_check, count)}
  end

  def check_rank_with_billing(combination_id, user_id) do
    alias RankTracker.Billing

    combination =
      TrackedCombination
      |> Repo.get!(combination_id)
      |> Repo.preload(keyword: :domain)

    check_info = %{
      combination_id: combination_id,
      keyword: combination.keyword.text,
      country: Locations.get_country_name(combination.country_code),
      domain: combination.keyword.domain.domain
    }

    case Billing.debit_for_rank_check(user_id, check_info) do
      {:ok, transaction} ->
        case check_rank(combination_id) do
          {:ok, result} ->
            Billing.update_transaction_with_result(transaction.id, %{
              "position" => result.position,
              "url" => result.url,
              "rank_result_id" => result.id
            })

            wallet = Billing.get_wallet(user_id)
            if wallet, do: Billing.maybe_trigger_auto_reload(wallet)
            {:ok, result}

          {:error, reason} ->
            Billing.refund_debit(user_id, check_info)
            {:error, reason}
        end

      {:error, :insufficient_funds} ->
        {:error, :insufficient_funds}
    end
  end

  def check_rank(combination_id) do
    combination =
      TrackedCombination
      |> Repo.get!(combination_id)
      |> Repo.preload(keyword: :domain)

    target_domain = combination.keyword.domain.domain
    language_code = Locations.get_language_code(combination.country_code)

    case Client.check_position(combination.keyword.text, combination.country_code, language_code) do
      {:ok, %{organic: organic, all_items: all_items}} ->
        match = find_domain_match(organic, target_domain)

        attrs = %{
          tracked_combination_id: combination.id,
          position: match && match["rank_absolute"],
          url: match && match["url"],
          domain: match && match["domain"],
          title: match && match["title"],
          cost: @cost_per_check,
          checked_at: DateTime.utc_now() |> DateTime.truncate(:second),
          raw_response: %{"items" => serialize_items(all_items)}
        }

        Tracking.create_result(attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def check_rank_live(keyword, country_code, target_domain \\ nil) do
    language_code = Locations.get_language_code(country_code)

    case Client.check_position(keyword, country_code, language_code) do
      {:ok, %{organic: organic}} ->
        results =
          Enum.map(organic, fn item ->
            %{
              position: item["rank_absolute"],
              url: item["url"],
              domain: item["domain"],
              title: item["title"],
              is_target: target_domain && domain_matches?(item["domain"], target_domain)
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_domain_match(items, nil), do: List.first(items)

  defp find_domain_match(items, target_domain) do
    Enum.find(items, fn item ->
      domain_matches?(item["domain"], target_domain)
    end)
  end

  defp domain_matches?(nil, _target), do: false
  defp domain_matches?(_domain, nil), do: false

  defp domain_matches?(domain, target) do
    normalized = String.downcase(domain) |> String.replace(~r{^www\.}, "")
    normalized == target || String.ends_with?(normalized, "." <> target)
  end

  defp serialize_items(items) do
    Enum.map(items, fn item ->
      Map.take(item, [
        "rank_absolute",
        "rank_group",
        "url",
        "domain",
        "title",
        "type",
        "description"
      ])
    end)
  end
end
