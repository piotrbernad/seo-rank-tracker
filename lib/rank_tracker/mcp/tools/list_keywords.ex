defmodule RankTracker.Mcp.Tools.ListKeywords do
  @moduledoc "List keyword+country combinations with latest positions"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Tracking
  alias RankTracker.DataForSeo.Locations

  schema do
    field :domain_id, {:required, :string}, description: "ID of the domain to list keywords for"
  end

  @impl true
  def execute(params, frame) do
    domain_id = params["domain_id"] || params[:domain_id]
    case get_user(frame) do
      {:ok, user} ->
        with {:ok, domain} <- fetch_domain(user.id, domain_id) do
          combos = Tracking.list_combinations(domain_id)

          text =
            if combos == [] do
              "No keywords tracked for #{domain.domain}."
            else
              header = "Keywords for #{domain.domain}:\n\n"

              lines =
                Enum.map(combos, fn c ->
                  latest = List.first(c.rank_results)
                  pos = if latest, do: latest.position || "100+", else: "--"
                  url = if latest, do: latest.url || "", else: ""
                  country = Locations.get_country_name(c.country_code)

                  "##{pos} | #{c.keyword.text} | #{country} | #{url} (combo: #{c.id})"
                end)

              header <> Enum.join(lines, "\n")
            end

          {:reply, Response.tool() |> Response.text(text), frame}
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
