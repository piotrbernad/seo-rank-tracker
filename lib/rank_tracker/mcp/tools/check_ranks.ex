defmodule RankTracker.Mcp.Tools.CheckRanks do
  @moduledoc "Live batch rank check for multiple keywords (not stored)"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.DataForSeo.Locations
  alias RankTracker.Rankings

  schema do
    field :entries, {:required, {:list, :map}},
      description:
        "List of entries to check. Each entry should have 'keyword' (string) and 'country' (string, name or code)"
  end

  @impl true
  def execute(params, frame) do
    entries = params["entries"] || params[:entries]

    unless is_list(entries) do
      {:error, Error.execution("'entries' must be a list of {keyword, country} objects"), frame}
    else
      results =
        Task.async_stream(
          entries,
          fn entry ->
            keyword = entry["keyword"] || entry[:keyword]
            country_raw = entry["country"] || entry[:country]

            with {:ok, country_code} <- Locations.resolve_country(country_raw),
                 {:ok, items} <- Rankings.check_rank_live(keyword, country_code) do
              top = List.first(items)

              %{
                keyword: keyword,
                country: Locations.get_country_name(country_code),
                position: top && top.position,
                url: top && top.url,
                domain: top && top.domain
              }
            else
              {:error, reason} ->
                %{keyword: keyword, country: country_raw, error: inspect(reason)}
            end
          end,
          max_concurrency: 3,
          timeout: 120_000
        )
        |> Enum.map(fn
          {:ok, result} -> result
          {:exit, reason} -> %{error: inspect(reason)}
        end)

      text =
        results
        |> Enum.map(fn
          %{error: err} = r ->
            "#{r[:keyword] || "unknown"} (#{r[:country] || "unknown"}): ERROR - #{err}"

          r ->
            pos = r.position || "not found"
            "#{r.keyword} (#{r.country}): ##{pos} - #{r.domain || "n/a"} - #{r.url || "n/a"}"
        end)
        |> Enum.join("\n")

      response =
        Response.tool()
        |> Response.text(text)

      {:reply, response, frame}
    end
  end
end
