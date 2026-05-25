defmodule RankTrackerWeb.DomainLive do
  use RankTrackerWeb, :live_view

  alias RankTracker.Tracking
  alias RankTracker.Rankings
  alias RankTracker.DataForSeo.Locations

  def mount(%{"id" => domain_id}, _session, socket) do
    domain = Tracking.get_user_domain!(socket.assigns.current_user.id, domain_id)
    combinations = Tracking.list_combinations(domain_id)

    {:ok,
     assign(socket,
       page_title: domain.domain,
       domain: domain,
       combinations: combinations,
       selected: MapSet.new(),
       checking: false,
       completed: 0,
       total: 0,
       results: %{}
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center justify-between mb-8">
        <div>
          <.link
            navigate={~p"/dashboard"}
            class="text-sm text-base-content/60 hover:text-base-content"
          >
            &larr; All Domains
          </.link>
          <h1 class="text-2xl font-bold">{@domain.domain}</h1>
        </div>
        <div class="flex gap-3">
          <.link navigate={~p"/domains/#{@domain.id}/keywords/new"} class="btn btn-primary">
            Add Keywords
          </.link>
        </div>
      </div>

      <%= if @combinations == [] do %>
        <div class="text-center py-16 bg-base-200 rounded-lg">
          <p class="text-lg text-base-content/60 mb-4">No keywords tracked for this domain yet.</p>
          <.link navigate={~p"/domains/#{@domain.id}/keywords/new"} class="btn btn-primary">
            Add keywords
          </.link>
        </div>
      <% else %>
        <div class="mb-6 flex items-center gap-4">
          <button phx-click="select_all" class="btn btn-sm btn-outline" disabled={@checking}>
            Select All
          </button>
          <button phx-click="deselect_all" class="btn btn-sm btn-outline" disabled={@checking}>
            Deselect All
          </button>

          <div class="flex-1"></div>

          <div class="text-right">
            <div class="text-lg font-semibold">
              ${format_cost(MapSet.size(@selected))}
            </div>
            <div class="text-sm text-base-content/60">
              {MapSet.size(@selected)} selected
            </div>
          </div>

          <button
            phx-click="start_refresh"
            class="btn btn-primary"
            disabled={MapSet.size(@selected) == 0 or @checking}
          >
            <%= if @checking do %>
              <span class="loading loading-spinner loading-sm"></span>
              {@completed}/{@total}
            <% else %>
              Refresh Selected
            <% end %>
          </button>
        </div>

        <%= if @checking do %>
          <progress class="progress progress-primary w-full mb-4" value={@completed} max={@total}>
          </progress>
        <% end %>

        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th class="w-10">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    checked={
                      MapSet.size(@selected) == length(@combinations) and length(@combinations) > 0
                    }
                    phx-click="toggle_all"
                    disabled={@checking}
                  />
                </th>
                <th>Keyword</th>
                <th>Country</th>
                <th>Position</th>
                <th>URL</th>
                <th>Last Checked</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for combo <- @combinations do %>
                <% latest = List.first(combo.rank_results) %>
                <tr class={if MapSet.member?(@selected, combo.id), do: "bg-primary/5", else: ""}>
                  <td>
                    <input
                      type="checkbox"
                      class="checkbox checkbox-sm"
                      checked={MapSet.member?(@selected, combo.id)}
                      phx-click="toggle_combo"
                      phx-value-id={combo.id}
                      disabled={@checking}
                    />
                  </td>
                  <td class="font-medium">{combo.keyword.text}</td>
                  <td>{Locations.get_country_name(combo.country_code)}</td>
                  <td>
                    <%= cond do %>
                      <% Map.has_key?(@results, combo.id) and match?({:ok, _}, @results[combo.id]) -> %>
                        <% {:ok, r} = @results[combo.id] %>
                        <span class={position_badge_class(r.position)}>
                          {r.position || "100+"}
                        </span>
                      <% Map.has_key?(@results, combo.id) -> %>
                        <span class="badge badge-error">Error</span>
                      <% not is_nil(latest) -> %>
                        <span class={position_badge_class(latest.position)}>
                          {latest.position || "100+"}
                        </span>
                      <% true -> %>
                        <span class="badge badge-ghost">--</span>
                    <% end %>
                  </td>
                  <td class="max-w-xs truncate text-sm">
                    <%= cond do %>
                      <% Map.has_key?(@results, combo.id) and match?({:ok, _}, @results[combo.id]) -> %>
                        <% {:ok, r} = @results[combo.id] %>
                        {r.url || "--"}
                      <% not is_nil(latest) -> %>
                        {latest.url || "--"}
                      <% true -> %>
                        --
                    <% end %>
                  </td>
                  <td class="text-sm text-base-content/60">
                    <%= if latest do %>
                      {Calendar.strftime(latest.checked_at, "%Y-%m-%d %H:%M")}
                    <% else %>
                      Never
                    <% end %>
                  </td>
                  <td>
                    <.link navigate={~p"/history/#{combo.id}"} class="btn btn-xs btn-ghost">
                      History
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_combo", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, id),
        do: MapSet.delete(socket.assigns.selected, id),
        else: MapSet.put(socket.assigns.selected, id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("select_all", _, socket) do
    {:noreply, assign(socket, selected: MapSet.new(socket.assigns.combinations, & &1.id))}
  end

  def handle_event("deselect_all", _, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_event("toggle_all", _, socket) do
    selected =
      if MapSet.size(socket.assigns.selected) == length(socket.assigns.combinations),
        do: MapSet.new(),
        else: MapSet.new(socket.assigns.combinations, & &1.id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("start_refresh", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected)
    pid = self()

    Task.start(fn ->
      Task.Supervisor.async_stream_nolink(
        RankTracker.TaskSupervisor,
        selected_ids,
        fn combo_id ->
          result = Rankings.check_rank(combo_id)
          send(pid, {:rank_result, combo_id, result})
          result
        end,
        max_concurrency: 3,
        ordered: false,
        timeout: 120_000
      )
      |> Stream.run()

      send(pid, :refresh_complete)
    end)

    {:noreply,
     assign(socket, checking: true, completed: 0, total: length(selected_ids), results: %{})}
  end

  def handle_info({:rank_result, combo_id, result}, socket) do
    results = Map.put(socket.assigns.results, combo_id, result)
    {:noreply, assign(socket, results: results, completed: socket.assigns.completed + 1)}
  end

  def handle_info(:refresh_complete, socket) do
    combinations = Tracking.list_combinations(socket.assigns.domain.id)

    {:noreply,
     socket
     |> assign(checking: false, combinations: combinations)
     |> put_flash(:info, "Rank check complete.")}
  end

  def handle_info({ref, _result}, socket) when is_reference(ref), do: {:noreply, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}

  defp format_cost(count), do: :erlang.float_to_binary(count * 0.002, decimals: 3)

  defp position_badge_class(nil), do: "badge badge-ghost"
  defp position_badge_class(pos) when pos <= 10, do: "badge badge-success"
  defp position_badge_class(pos) when pos <= 30, do: "badge badge-warning"
  defp position_badge_class(pos) when pos <= 50, do: "badge badge-info"
  defp position_badge_class(_), do: "badge badge-error"
end
