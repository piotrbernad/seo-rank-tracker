defmodule RankTracker.Mcp.Tools.AddKeywords do
  @moduledoc "Add keywords and countries to a domain"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Tracking
  alias RankTracker.DataForSeo.Locations

  schema do
    field :domain_id, {:required, :string}, description: "ID of the domain to add keywords to"

    field :keywords, {:required, {:list, :string}}, description: "List of keywords to track"

    field :countries, {:required, {:list, :string}},
      description: "List of countries (names like 'United States' or location codes like '2840')"
  end

  @impl true
  def execute(params, frame) do
    domain_id = params["domain_id"] || params[:domain_id]
    keywords = params["keywords"] || params[:keywords]
    countries = params["countries"] || params[:countries]
    case get_user(frame) do
      {:ok, user} ->
        with {:ok, _domain} <- fetch_domain(user.id, domain_id),
             {:ok, country_codes} <- resolve_countries(countries) do
          {_count, kws} = Tracking.create_keywords(domain_id, keywords)
          keyword_ids = Enum.map(kws, & &1.id)

          existing_ids =
            Tracking.list_keywords(domain_id)
            |> Enum.filter(fn k ->
              String.downcase(k.text) in Enum.map(keywords, &String.downcase(String.trim(&1)))
            end)
            |> Enum.map(& &1.id)

          all_ids = Enum.uniq(keyword_ids ++ existing_ids)
          {combo_count, _} = Tracking.create_combinations_for_keywords(all_ids, country_codes)

          text =
            "Added #{length(keywords)} keyword(s) × #{length(country_codes)} country/countries = #{combo_count} combination(s)."

          {:reply, Response.tool() |> Response.text(text), frame}
        else
          {:error, %Error{} = err} -> {:error, err, frame}
          {:error, msg} -> {:error, Error.execution(to_string(msg)), frame}
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

  defp resolve_countries(countries) do
    results =
      Enum.reduce_while(countries, {:ok, []}, fn c, {:ok, acc} ->
        case Locations.resolve_country(c) do
          {:ok, code} -> {:cont, {:ok, [code | acc]}}
          {:error, _} -> {:halt, {:error, Error.execution("Invalid country: #{c}")}}
        end
      end)

    case results do
      {:ok, codes} -> {:ok, Enum.reverse(codes)}
      error -> error
    end
  end

  defp get_user(%{assigns: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  defp get_user(_), do: {:error, Error.execution("Not authenticated")}
end
