defmodule RankTrackerWeb.AddKeywordsLive do
  use RankTrackerWeb, :live_view

  alias RankTracker.Tracking
  alias RankTracker.DataForSeo.Locations

  def mount(%{"domain_id" => domain_id}, _session, socket) do
    domain = Tracking.get_user_domain!(socket.assigns.current_user.id, domain_id)

    {:ok,
     assign(socket,
       page_title: "Add Keywords - #{domain.domain}",
       domain: domain,
       keywords_text: "",
       selected_countries: MapSet.new(),
       countries: Locations.for_select(),
       error: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <div class="flex items-center justify-between mb-8">
        <div>
          <.link
            navigate={~p"/domains/#{@domain.id}"}
            class="text-sm text-base-content/60 hover:text-base-content"
          >
            &larr; {@domain.domain}
          </.link>
          <h1 class="text-2xl font-bold">Add Keywords</h1>
        </div>
      </div>

      <%= if @error do %>
        <div class="alert alert-error mb-4">{@error}</div>
      <% end %>

      <form phx-submit="save" class="space-y-6">
        <div class="form-control">
          <label class="label">
            <span class="label-text font-medium">Keywords (one per line)</span>
          </label>
          <textarea
            name="keywords"
            rows="8"
            class="textarea textarea-bordered w-full font-mono"
            placeholder="best seo tools
    rank tracking software
    keyword research api"
            phx-change="update_keywords"
          ><%= @keywords_text %></textarea>
          <label class="label">
            <span class="label-text-alt">
              {keyword_count(@keywords_text)} keyword(s) entered
            </span>
          </label>
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text font-medium">Countries</span>
          </label>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-2 max-h-64 overflow-y-auto p-3 border rounded-lg">
            <%= for {name, code} <- @countries do %>
              <label class="flex items-center gap-2 cursor-pointer hover:bg-base-200 p-1 rounded">
                <input
                  type="checkbox"
                  name="countries[]"
                  value={code}
                  checked={MapSet.member?(@selected_countries, code)}
                  class="checkbox checkbox-sm"
                  phx-click="toggle_country"
                  phx-value-code={code}
                />
                <span class="text-sm">{name}</span>
              </label>
            <% end %>
          </div>
          <label class="label">
            <span class="label-text-alt">
              {MapSet.size(@selected_countries)} country/countries selected
            </span>
          </label>
        </div>

        <div class="flex items-center gap-4">
          <button
            type="submit"
            class="btn btn-primary"
            disabled={keyword_count(@keywords_text) == 0 or MapSet.size(@selected_countries) == 0}
          >
            Add {keyword_count(@keywords_text) * MapSet.size(@selected_countries)} combination(s)
          </button>
          <span class="text-sm text-base-content/60">
            Estimated cost per refresh: ${:erlang.float_to_binary(
              keyword_count(@keywords_text) * MapSet.size(@selected_countries) * 0.002,
              decimals: 3
            )}
          </span>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("update_keywords", %{"keywords" => text}, socket) do
    {:noreply, assign(socket, keywords_text: text)}
  end

  def handle_event("toggle_country", %{"code" => code_str}, socket) do
    code = String.to_integer(code_str)

    selected =
      if MapSet.member?(socket.assigns.selected_countries, code),
        do: MapSet.delete(socket.assigns.selected_countries, code),
        else: MapSet.put(socket.assigns.selected_countries, code)

    {:noreply, assign(socket, selected_countries: selected)}
  end

  def handle_event("save", %{"keywords" => keywords_text}, socket) do
    domain = socket.assigns.domain
    country_codes = MapSet.to_list(socket.assigns.selected_countries)

    texts =
      keywords_text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if texts == [] or country_codes == [] do
      {:noreply, assign(socket, error: "Please enter at least one keyword and select a country.")}
    else
      {_count, keywords} = Tracking.create_keywords(domain.id, texts)
      keyword_ids = Enum.map(keywords, & &1.id)

      existing_keyword_ids =
        Tracking.list_keywords(domain.id)
        |> Enum.filter(fn k ->
          String.downcase(String.trim(k.text)) in Enum.map(
            texts,
            &String.downcase(String.trim(&1))
          )
        end)
        |> Enum.map(& &1.id)

      all_keyword_ids = Enum.uniq(keyword_ids ++ existing_keyword_ids)
      Tracking.create_combinations_for_keywords(all_keyword_ids, country_codes)

      {:noreply,
       socket
       |> put_flash(:info, "Keywords and tracking combinations created.")
       |> push_navigate(to: ~p"/domains/#{domain.id}")}
    end
  end

  defp keyword_count(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> length()
  end
end
