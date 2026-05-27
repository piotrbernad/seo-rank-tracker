defmodule RankTracker.Mcp.Tools.GetHistory do
  @moduledoc "Get ranking history for a keyword+country combination"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Tracking
  alias RankTracker.DataForSeo.Locations

  schema do
    field :combination_id, {:required, :string},
      description: "ID of the keyword+country combination to get history for"
  end

  @impl true
  def execute(%{"combination_id" => combination_id}, frame) do
    case get_user(frame) do
      {:ok, _user} ->
        try do
          combo = Tracking.get_combination!(combination_id)
          results = Tracking.list_results(combination_id, limit: 20)
          country = Locations.get_country_name(combo.country_code)

          text =
            if results == [] do
              "No history for '#{combo.keyword.text}' in #{country}."
            else
              header =
                "Rank history for '#{combo.keyword.text}' in #{country} (#{combo.keyword.domain.domain}):\n\n"

              lines =
                Enum.map(results, fn r ->
                  pos = r.position || "100+"
                  date = Calendar.strftime(r.checked_at, "%Y-%m-%d %H:%M")
                  url = r.url || ""
                  "#{date} | ##{pos} | #{url}"
                end)

              header <> Enum.join(lines, "\n")
            end

          {:reply, Response.tool() |> Response.text(text), frame}
        rescue
          Ecto.NoResultsError ->
            {:error, Error.execution("Combination not found"), frame}
        end

      {:error, err} ->
        {:error, err, frame}
    end
  end

  defp get_user(%{assigns: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  defp get_user(_), do: {:error, Error.execution("Not authenticated")}
end
