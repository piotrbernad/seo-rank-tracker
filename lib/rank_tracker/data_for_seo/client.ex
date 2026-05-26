defmodule RankTracker.DataForSeo.Client do
  require Logger

  @live_url "https://api.dataforseo.com/v3/serp/google/organic/live/advanced"

  def check_position(keyword, location_code, language_code) do
    with {:ok, auth_token} <- fetch_auth_token() do
      body = [
        %{
          "language_code" => language_code,
          "location_code" => location_code,
          "keyword" => keyword,
          "device" => "desktop",
          "depth" => 100
        }
      ]

      request =
        Req.new(
          url: @live_url,
          method: :post,
          json: body,
          headers: [
            {"Authorization", "Basic #{auth_token}"},
            {"Content-Type", "application/json"}
          ],
          receive_timeout: 60_000,
          connect_options: [
            transport_opts: [cacertfile: CAStore.file_path()],
            protocols: [:http1]
          ]
        )

      case Req.request(request) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          parse_result(body)

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("DataForSEO API returned status #{status}: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.error("DataForSEO API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp fetch_auth_token do
    case Application.get_env(:rank_tracker, :dataforseo_auth_token) do
      nil -> {:error, :missing_dataforseo_auth_token}
      token -> {:ok, token}
    end
  end

  defp parse_result(body) do
    with tasks when is_list(tasks) <- Map.get(body, "tasks"),
         [task | _] <- tasks,
         result when is_list(result) <- Map.get(task, "result"),
         [first_result | _] <- result do
      items = first_result["items"] || []
      organic = Enum.filter(items, &(&1["type"] == "organic"))

      {:ok,
       %{
         organic: organic,
         all_items: items,
         total_count: first_result["items_count"],
         se_results_count: first_result["se_results_count"]
       }}
    else
      _ -> {:error, :invalid_response_structure}
    end
  end
end
