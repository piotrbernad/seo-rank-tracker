defmodule RankTracker.Mcp.Tools.CheckRank do
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.DataForSeo.Locations
  alias RankTracker.Rankings

  schema do
    field :keyword, {:required, :string}, description: "The search keyword to check ranking for"

    field :country, {:required, :string},
      description: "Country name (e.g. 'United States') or DataForSEO location code (e.g. '2840')"

    field :domain, :string,
      description: "Target domain to find in results (e.g. 'example.com'). Optional."
  end

  @impl true
  def execute(params, frame) do
    keyword = params["keyword"]
    country_raw = params["country"]
    target_domain = params["domain"]

    with {:ok, country_code} <- Locations.resolve_country(country_raw),
         {:ok, results} <- Rankings.check_rank_live(keyword, country_code, target_domain) do
      top_10 = Enum.take(results, 10)

      text =
        if top_10 == [] do
          "No organic results found for '#{keyword}' in #{Locations.get_country_name(country_code)}."
        else
          header =
            "Top results for '#{keyword}' in #{Locations.get_country_name(country_code)}:\n\n"

          lines =
            Enum.map(top_10, fn r ->
              marker = if r.is_target, do: " <<<", else: ""
              "##{r.position} - #{r.domain}#{marker}\n  #{r.title}\n  #{r.url}"
            end)

          header <> Enum.join(lines, "\n\n")
        end

      response =
        Response.tool()
        |> Response.text(text)

      {:reply, response, frame}
    else
      {:error, :invalid_country} ->
        {:error, Error.execution("Invalid country: #{country_raw}"), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to check rank: #{inspect(reason)}"), frame}
    end
  end
end
