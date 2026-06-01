defmodule RankTracker.Mcp.Tools.RefreshRanks do
  @moduledoc "Refresh rankings for all keywords of a domain"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Tracking
  alias RankTracker.Rankings
  alias RankTracker.Billing
  alias RankTracker.DataForSeo.Locations

  schema do
    field :domain_id, {:required, :string},
      description:
        "ID of the domain to refresh rankings for. Refreshes all keyword+country combinations."
  end

  @impl true
  def execute(params, frame) do
    domain_id = params["domain_id"] || params[:domain_id]
    case get_user(frame) do
      {:ok, user} ->
        with {:ok, domain} <- fetch_domain(user.id, domain_id) do
          combos = Tracking.list_combinations(domain_id)

          if combos == [] do
            {:reply,
             Response.tool()
             |> Response.text("No keywords to refresh for #{domain.domain}."), frame}
          else
            count = length(combos)

            if not Billing.sufficient_funds?(user.id, count) do
              balance = Billing.get_balance(user.id)
              needed = Billing.estimate_cost(count)

              {:error,
               Error.execution(
                 "Insufficient funds. Need $#{Decimal.round(needed, 4)} but balance is $#{Decimal.round(balance, 2)}."
               ), frame}
            else
              results =
                combos
                |> Task.async_stream(
                  fn combo ->
                    case Rankings.check_rank_with_billing(combo.id, user.id) do
                      {:ok, result} ->
                        {:ok, combo, result}

                      {:error, reason} ->
                        {:error, combo, reason}
                    end
                  end,
                  max_concurrency: 10,
                  timeout: 30_000
                )
                |> Enum.map(fn
                  {:ok, {:ok, combo, result}} ->
                    pos = result.position || "100+"
                    url = result.url || ""
                    country = Locations.get_country_name(combo.country_code)
                    "##{pos} | #{combo.keyword.text} | #{country} | #{url}"

                  {:ok, {:error, combo, reason}} ->
                    "ERR | #{combo.keyword.text} | #{inspect(reason)}"

                  {:exit, reason} ->
                    "ERR | timeout: #{inspect(reason)}"
                end)

              text =
                "Refreshed #{count} combination(s) for #{domain.domain}:\n\n" <>
                  Enum.join(results, "\n")

              {:reply, Response.tool() |> Response.text(text), frame}
            end
          end
        else
          {:error, err} -> {:error, err, frame}
        end

      {:error, err} ->
        {:error, err, frame}
    end
  end

  defp fetch_domain(user_id, domain_id) do
    try do
      {:ok, Tracking.get_user_domain!(user_id, domain_id)}
    rescue
      Ecto.NoResultsError -> {:error, Error.execution("Domain not found")}
    end
  end

  defp get_user(%{assigns: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  defp get_user(_), do: {:error, Error.execution("Not authenticated")}
end
