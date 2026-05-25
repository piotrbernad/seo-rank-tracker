defmodule RankTracker.Mcp.Tools.AddDomain do
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Tracking

  schema do
    field :domain, {:required, :string}, description: "Domain to track (e.g. 'example.com')"
  end

  @impl true
  def execute(%{"domain" => domain}, frame) do
    case get_user(frame) do
      {:ok, user} ->
        case Tracking.create_domain(user.id, domain) do
          {:ok, d} ->
            text = "Domain '#{d.domain}' added successfully (id: #{d.id})."
            {:reply, Response.tool() |> Response.text(text), frame}

          {:error, changeset} ->
            msg =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              |> Enum.map_join(", ", fn {_k, v} -> Enum.join(v, ", ") end)

            {:error, Error.execution("Failed to add domain: #{msg}"), frame}
        end

      {:error, err} ->
        {:error, err, frame}
    end
  end

  defp get_user(%{assigns: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  defp get_user(_), do: {:error, Error.execution("Not authenticated")}
end
