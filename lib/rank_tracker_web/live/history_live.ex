defmodule RankTrackerWeb.HistoryLive do
  use RankTrackerWeb, :live_view

  alias RankTracker.Tracking
  alias RankTracker.DataForSeo.Locations

  def mount(%{"id" => combination_id}, _session, socket) do
    combination = Tracking.get_combination!(combination_id)
    results = Tracking.list_results(combination_id)
    target_domain = combination.keyword.domain.domain

    {:ok,
     assign(socket,
       page_title: "History - #{combination.keyword.text}",
       combination: combination,
       target_domain: target_domain,
       results: results,
       expanded: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <div class="flex items-center justify-between mb-8">
        <div>
          <.link
            navigate={~p"/dashboard"}
            class="text-sm text-base-content/60 hover:text-base-content"
          >
            &larr; Dashboard
          </.link>
          <h1 class="text-2xl font-bold">{@combination.keyword.text}</h1>
          <p class="text-base-content/60">
            {Locations.get_country_name(@combination.country_code)} &middot; {@target_domain}
          </p>
        </div>
      </div>

      <%= if @results == [] do %>
        <div class="text-center py-16 bg-base-200 rounded-lg">
          <p class="text-lg text-base-content/60">
            No results yet. Run a refresh to check rankings.
          </p>
        </div>
      <% else %>
        <div class="space-y-2">
          <%= for {result, index} <- Enum.with_index(@results) do %>
            <div class="card bg-base-100 border border-base-300">
              <div
                class="card-body py-3 px-4 cursor-pointer hover:bg-base-200/50 transition-colors"
                phx-click="toggle_expand"
                phx-value-id={result.id}
              >
                <div class="flex items-center gap-4">
                  <div class="text-sm text-base-content/60 w-36">
                    {Calendar.strftime(result.checked_at, "%Y-%m-%d %H:%M")}
                  </div>
                  <div>
                    <span class={position_badge_class(result.position)}>
                      {result.position || "Not in top 100"}
                    </span>
                  </div>
                  <div>
                    <%= case position_change(result, Enum.at(@results, index + 1)) do %>
                      <% nil -> %>
                        <span></span>
                      <% 0 -> %>
                        <span class="text-base-content/40">=</span>
                      <% change when change > 0 -> %>
                        <span class="text-error text-sm">&#9660; {change}</span>
                      <% change -> %>
                        <span class="text-success text-sm">&#9650; {abs(change)}</span>
                    <% end %>
                  </div>
                  <div class="flex-1 truncate text-sm text-base-content/60">
                    {result.url || ""}
                  </div>
                  <div class="text-base-content/40">
                    <%= if @expanded == result.id do %>
                      &#9650;
                    <% else %>
                      &#9660;
                    <% end %>
                  </div>
                </div>
              </div>

              <%= if @expanded == result.id do %>
                <div class="border-t border-base-300 px-4 py-3">
                  <h3 class="text-sm font-semibold mb-2 text-base-content/70">
                    Full SERP Results
                  </h3>
                  <%= if serp_items(result) == [] do %>
                    <p class="text-sm text-base-content/50">No SERP data stored for this check.</p>
                  <% else %>
                    <table class="table table-xs w-full">
                      <thead>
                        <tr>
                          <th class="w-12">#</th>
                          <th class="w-20">Type</th>
                          <th>Title / Domain</th>
                          <th>URL</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for item <- serp_items(result) do %>
                          <tr class={
                            if is_target?(item, @target_domain),
                              do: "bg-success/10 font-semibold",
                              else: ""
                          }>
                            <td class="font-mono text-base-content/60">
                              {item["rank_absolute"] || item["position"]}
                            </td>
                            <td>
                              <span class={"badge badge-xs " <> type_badge(item["type"])}>
                                {item["type"] || "?"}
                              </span>
                            </td>
                            <td>
                              <div class="truncate max-w-sm">{item["title"] || "--"}</div>
                              <div class="text-xs text-base-content/50">{item["domain"]}</div>
                            </td>
                            <td class="max-w-sm">
                              <div class="truncate text-xs text-base-content/60">
                                {item["url"] || "--"}
                              </div>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="mt-6 text-sm text-base-content/60">
          Total checks: {length(@results)} |
          Total cost: ${Enum.reduce(@results, Decimal.new(0), fn r, acc ->
            Decimal.add(acc, r.cost)
          end)}
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    expanded = if socket.assigns.expanded == id, do: nil, else: id
    {:noreply, assign(socket, expanded: expanded)}
  end

  defp serp_items(%{raw_response: %{"items" => items}}) when is_list(items), do: items
  defp serp_items(_), do: []

  defp is_target?(item, target_domain) do
    domain = item["domain"] || ""
    normalized = String.downcase(domain) |> String.replace(~r{^www\.}, "")
    normalized == target_domain || String.ends_with?(normalized, "." <> target_domain)
  end

  defp position_change(_current, nil), do: nil

  defp position_change(current, previous) do
    case {current.position, previous.position} do
      {nil, _} -> nil
      {_, nil} -> nil
      {curr, prev} -> curr - prev
    end
  end

  defp type_badge("organic"), do: "badge-success"
  defp type_badge("paid"), do: "badge-error"
  defp type_badge("local_pack"), do: "badge-info"
  defp type_badge("featured_snippet"), do: "badge-warning"
  defp type_badge("knowledge_graph"), do: "badge-info"
  defp type_badge("people_also_ask"), do: "badge-ghost"
  defp type_badge("images"), do: "badge-ghost"
  defp type_badge("video"), do: "badge-ghost"
  defp type_badge(_), do: "badge-ghost"

  defp position_badge_class(nil), do: "badge badge-ghost"
  defp position_badge_class(pos) when pos <= 10, do: "badge badge-success"
  defp position_badge_class(pos) when pos <= 30, do: "badge badge-warning"
  defp position_badge_class(pos) when pos <= 50, do: "badge badge-info"
  defp position_badge_class(_), do: "badge badge-error"
end
