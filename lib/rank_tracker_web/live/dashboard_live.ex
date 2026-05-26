defmodule RankTrackerWeb.DashboardLive do
  use RankTrackerWeb, :live_view

  alias RankTracker.Tracking
  alias RankTracker.Billing
  alias RankTracker.RankChecker
  alias RankTracker.DataForSeo.Locations

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    status =
      if connected?(socket) do
        RankChecker.subscribe(user_id)
        RankChecker.get_status(user_id)
      else
        %{queued: [], active: [], total: 0, busy: false}
      end

    domains = Tracking.list_domains(user_id)
    combinations = Tracking.list_combinations_by_user(user_id)
    grouped = Enum.group_by(combinations, fn c -> c.keyword.domain end)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       domains: domains,
       grouped: grouped,
       new_domain: "",
       selected: MapSet.new(),
       checking: status.busy,
       completed: 0,
       total: status.total,
       results: %{},
       in_flight: MapSet.new(status.active)
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-12">
        <span class="section-label">Dashboard</span>
        <h1 class="text-2xl font-light text-[oklch(8%_0.005_260)] mt-1">
          Keyword Positions
        </h1>
      </div>

      <%= if @checking do %>
        <div class="mb-8 h-px bg-[oklch(88%_0.005_260)] relative overflow-hidden">
          <div
            class="absolute inset-y-0 left-0 bg-[oklch(42%_0.16_155)] transition-all duration-500"
            style={"width: #{if @total > 0, do: @completed / @total * 100, else: 0}%"}
          >
          </div>
        </div>
      <% end %>

      <%= if @domains == [] do %>
        <div class="py-24 text-center">
          <p class="font-mono text-sm text-[oklch(60%_0.005_260)]">
            [ No domains tracked yet ]
          </p>
        </div>
      <% else %>
        <div class="flex items-center gap-4 mb-6">
          <button phx-click="select_all" class="btn-action" disabled={@checking}>
            Select All
          </button>
          <button phx-click="deselect_all" class="btn-action" disabled={@checking}>
            Clear
          </button>
          <div class="flex-1"></div>
          <%= if MapSet.size(@selected) > 0 or @checking do %>
            <span class="font-mono text-xs text-[oklch(50%_0.005_260)]">
              {MapSet.size(@selected)} selected &middot; ${format_cost(MapSet.size(@selected))}
            </span>
          <% end %>
          <button
            phx-click="start_refresh"
            class="btn-action btn-action-primary"
            disabled={MapSet.size(@selected) == 0 or @checking}
          >
            <%= if @checking do %>
              Checking {@completed}/{@total}
            <% else %>
              Refresh Selected
            <% end %>
          </button>
        </div>

        <%= for domain <- @domains do %>
          <% combos = Map.get(@grouped, domain, []) %>
          <div class="mb-12">
            <% domain_selected = Enum.filter(combos, &MapSet.member?(@selected, &1.id)) %>
            <% domain_done =
              Enum.count(domain_selected, &Map.has_key?(@results, &1.id)) %>
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center gap-3">
                <input
                  type="checkbox"
                  class="w-3.5 h-3.5 accent-[oklch(25%_0.005_260)] cursor-pointer"
                  checked={all_selected?(combos, @selected)}
                  phx-click="toggle_domain"
                  phx-value-domain-id={domain.id}
                  disabled={@checking}
                />
                <h2 class="font-mono text-base text-[oklch(12%_0.005_260)] tracking-wide">
                  {domain.domain}
                </h2>
                <%= if @checking and length(domain_selected) > 0 do %>
                  <span class="font-mono text-xs text-[oklch(50%_0.005_260)]">
                    Refreshing... ({domain_done}/{length(domain_selected)})
                  </span>
                <% end %>
              </div>
              <.link
                navigate={~p"/domains/#{domain.id}/keywords/new"}
                class="font-mono text-xs text-[oklch(55%_0.005_260)] hover:text-[oklch(25%_0.005_260)] uppercase tracking-wider transition-colors"
              >
                + Add Keywords
              </.link>
            </div>

            <%= if combos == [] do %>
              <div class="py-12 text-center border border-dotted border-[oklch(85%_0.005_260)]">
                <p class="font-mono text-xs text-[oklch(65%_0.005_260)]">
                  [ No keywords ]
                </p>
                <.link
                  navigate={~p"/domains/#{domain.id}/keywords/new"}
                  class="font-mono text-xs text-[oklch(50%_0.005_260)] hover:text-[oklch(20%_0.005_260)] mt-2 inline-block transition-colors"
                >
                  Add keywords to track
                </.link>
              </div>
            <% else %>
              <table class="data-table table-fixed w-full">
                <colgroup>
                  <col class="w-[3%]" />
                  <col class="w-[28%]" />
                  <col class="w-[8%]" />
                  <col class="w-[9%]" />
                  <col class="w-[30%]" />
                  <col class="w-[14%]" />
                  <col class="w-[8%]" />
                </colgroup>
                <thead>
                  <tr>
                    <th></th>
                    <th>Keyword</th>
                    <th>Country</th>
                    <th>Position</th>
                    <th>Ranking URL</th>
                    <th>Checked</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for combo <- combos do %>
                    <% latest = List.first(combo.rank_results) %>
                    <tr class={if MapSet.member?(@selected, combo.id), do: "row-selected", else: ""}>
                      <td>
                        <input
                          type="checkbox"
                          class="w-3.5 h-3.5 accent-[oklch(25%_0.005_260)] cursor-pointer"
                          checked={MapSet.member?(@selected, combo.id)}
                          phx-click="toggle_combo"
                          phx-value-id={combo.id}
                          disabled={@checking}
                        />
                      </td>
                      <td class="text-[oklch(12%_0.005_260)]">
                        <span class="flex items-center gap-2">
                          {combo.keyword.text}
                          <%= if MapSet.member?(@in_flight, combo.id) do %>
                            <span
                              class="inline-block w-3 h-3 border border-[oklch(40%_0.005_260)] border-t-[oklch(12%_0.005_260)] rounded-full animate-spin"
                              title="Checking..."
                            >
                            </span>
                          <% end %>
                        </span>
                      </td>
                      <td class="font-mono text-xs text-[oklch(45%_0.005_260)]">
                        {Locations.get_country_iso(combo.country_code)}
                      </td>
                      <td>
                        <%= cond do %>
                          <% Map.has_key?(@results, combo.id) and
                               match?({:ok, _}, @results[combo.id]) -> %>
                            <% {:ok, r} = @results[combo.id] %>
                            <span class={"pos-badge " <> pos_class(r.position)}>
                              {r.position || "--"}
                            </span>
                          <% Map.has_key?(@results, combo.id) -> %>
                            <span class="pos-badge pos-100">err</span>
                          <% not is_nil(latest) -> %>
                            <span class={"pos-badge " <> pos_class(latest.position)}>
                              {latest.position || "--"}
                            </span>
                          <% true -> %>
                            <span class="pos-badge pos-none">&mdash;</span>
                        <% end %>
                      </td>
                      <td class="max-w-xs truncate text-xs text-[oklch(55%_0.005_260)]">
                        <%= cond do %>
                          <% Map.has_key?(@results, combo.id) and
                               match?({:ok, _}, @results[combo.id]) -> %>
                            <% {:ok, r} = @results[combo.id] %>
                            {r.url || ""}
                          <% not is_nil(latest) -> %>
                            {latest.url || ""}
                          <% true -> %>
                        <% end %>
                      </td>
                      <td class="font-mono text-xs text-[oklch(62%_0.005_260)]">
                        <%= if latest do %>
                          {Calendar.strftime(latest.checked_at, "%m/%d %H:%M")}
                        <% end %>
                      </td>
                      <td>
                        <.link
                          navigate={~p"/history/#{combo.id}"}
                          class="btn-action text-[0.625rem] py-1 px-2"
                        >
                          History
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% end %>
          </div>
        <% end %>
      <% end %>

      <div class="mt-12 border-t border-dotted border-[oklch(85%_0.005_260)] pt-8">
        <form phx-submit="add_domain" class="flex gap-3 items-center">
          <input
            type="text"
            name="domain"
            value={@new_domain}
            placeholder="Add domain to track..."
            class="input-field flex-1"
            phx-change="update_domain"
          />
          <button type="submit" class="btn-action" disabled={@new_domain == ""}>
            Add Domain
          </button>
        </form>
      </div>
    </div>
    """
  end

  def handle_event("update_domain", %{"domain" => domain}, socket) do
    {:noreply, assign(socket, new_domain: domain)}
  end

  def handle_event("add_domain", %{"domain" => domain}, socket) do
    case Tracking.create_domain(socket.assigns.current_user.id, domain) do
      {:ok, _domain} ->
        {:noreply, reload(socket) |> assign(new_domain: "") |> put_flash(:info, "Domain added")}

      {:error, changeset} ->
        msg =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          |> Enum.map_join(", ", fn {_k, v} -> Enum.join(v, ", ") end)

        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("toggle_combo", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, id),
        do: MapSet.delete(socket.assigns.selected, id),
        else: MapSet.put(socket.assigns.selected, id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("toggle_domain", %{"domain-id" => domain_id}, socket) do
    combos = Map.get(socket.assigns.grouped, find_domain(socket, domain_id), [])
    combo_ids = MapSet.new(combos, & &1.id)

    selected =
      if MapSet.subset?(combo_ids, socket.assigns.selected),
        do: MapSet.difference(socket.assigns.selected, combo_ids),
        else: MapSet.union(socket.assigns.selected, combo_ids)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("select_all", _, socket) do
    all_ids =
      socket.assigns.grouped
      |> Enum.flat_map(fn {_d, combos} -> Enum.map(combos, & &1.id) end)
      |> MapSet.new()

    {:noreply, assign(socket, selected: all_ids)}
  end

  def handle_event("deselect_all", _, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_event("start_refresh", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected)
    user_id = socket.assigns.current_user.id
    count = length(selected_ids)

    case RankChecker.enqueue(user_id, selected_ids) do
      {:ok, _job_id} ->
        {:noreply,
         assign(socket,
           checking: true,
           completed: 0,
           total: count,
           results: %{},
           in_flight: MapSet.new()
         )}

      {:error, :insufficient_funds} ->
        balance = Billing.get_balance(user_id)
        needed = Billing.estimate_cost(count)

        {:noreply,
         put_flash(
           socket,
           :error,
           "Insufficient funds. Need $#{Decimal.round(needed, 4)} but balance is $#{Decimal.round(balance, 2)}. Add funds first."
         )}
    end
  end

  # PubSub callbacks from RankChecker

  def handle_info({:rank_checking, combo_id}, socket) do
    {:noreply, assign(socket, in_flight: MapSet.put(socket.assigns.in_flight, combo_id))}
  end

  def handle_info({:rank_checked, combo_id, result}, socket) do
    results = Map.put(socket.assigns.results, combo_id, result)
    in_flight = MapSet.delete(socket.assigns.in_flight, combo_id)

    {:noreply,
     assign(socket,
       results: results,
       in_flight: in_flight,
       completed: socket.assigns.completed + 1
     )}
  end

  def handle_info({:job_started, _job_id, _count}, socket) do
    {:noreply, socket}
  end

  def handle_info({:job_complete, _job_id}, socket) do
    balance = Billing.get_balance(socket.assigns.current_user.id)

    {:noreply,
     reload(socket)
     |> assign(checking: false, wallet_balance: balance)
     |> put_flash(:info, "Rank check complete.")}
  end

  defp reload(socket) do
    user_id = socket.assigns.current_user.id
    domains = Tracking.list_domains(user_id)
    combinations = Tracking.list_combinations_by_user(user_id)
    grouped = Enum.group_by(combinations, fn c -> c.keyword.domain end)
    assign(socket, domains: domains, grouped: grouped)
  end

  defp find_domain(socket, domain_id) do
    Enum.find(socket.assigns.domains, &(&1.id == domain_id))
  end

  defp all_selected?(combos, selected) do
    combos != [] and Enum.all?(combos, &MapSet.member?(selected, &1.id))
  end

  defp format_cost(count) do
    Billing.estimate_cost(count) |> Decimal.round(4) |> Decimal.to_string()
  end

  defp pos_class(nil), do: "pos-none"
  defp pos_class(pos) when pos <= 10, do: "pos-top10"
  defp pos_class(pos) when pos <= 30, do: "pos-top30"
  defp pos_class(pos) when pos <= 50, do: "pos-top50"
  defp pos_class(_), do: "pos-100"
end
