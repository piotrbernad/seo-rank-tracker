defmodule RankTracker.Mcp.Tools.GetBalance do
  @moduledoc "Check account wallet balance"
  use Hermes.Server.Component, type: :tool

  alias Hermes.MCP.Error
  alias Hermes.Server.Response
  alias RankTracker.Billing

  schema do
  end

  @impl true
  def execute(_params, frame) do
    case get_user(frame) do
      {:ok, user} ->
        balance = Billing.get_balance(user.id)
        price = Billing.price_per_check()
        checks = if Decimal.compare(price, 0) == :gt, do: Decimal.div_int(balance, price), else: 0

        text =
          "Balance: $#{Decimal.round(balance, 4)}\n" <>
            "Price per check: $#{Decimal.round(price, 4)}\n" <>
            "Remaining checks: ~#{checks}"

        {:reply, Response.tool() |> Response.text(text), frame}

      {:error, err} ->
        {:error, err, frame}
    end
  end

  defp get_user(%{assigns: %{current_user: user}}) when not is_nil(user), do: {:ok, user}
  defp get_user(_), do: {:error, Error.execution("Not authenticated")}
end
