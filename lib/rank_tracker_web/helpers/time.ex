defmodule RankTrackerWeb.Helpers.Time do
  def format_time(nil, _timezone), do: ""
  def format_time(nil, _timezone, _format), do: ""

  def format_time(datetime, timezone, format \\ "%m/%d %H:%M") do
    datetime
    |> to_datetime()
    |> DateTime.shift_zone(timezone || "UTC")
    |> case do
      {:ok, shifted} -> Calendar.strftime(shifted, format)
      _ -> Calendar.strftime(datetime, format)
    end
  end

  defp to_datetime(%DateTime{} = dt), do: dt
  defp to_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  defp to_datetime(other), do: other
end
