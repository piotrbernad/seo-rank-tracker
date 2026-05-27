defmodule RankTracker.Mcp.Tools.ListDomains do
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Tracking

  def description, do: "List all tracked domains"

  schema do
  end

  @impl true
  def execute(_params, frame) do
    case get_user(frame) do
      {:ok, user} ->
        domains = Tracking.list_domains(user.id)

        text =
          if domains == [] do
            "No domains tracked yet."
          else
            header = "Tracked domains:\n\n"

            lines =
              Enum.map(domains, fn d ->
                "- #{d.domain} (id: #{d.id})"
              end)

            header <> Enum.join(lines, "\n")
          end

        {:reply, Response.tool() |> Response.text(text), frame}

      {:error, err} ->
        {:error, err, frame}
    end
  end

  defp get_user(%{assigns: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  defp get_user(_), do: {:error, Error.execution("Not authenticated")}
end
