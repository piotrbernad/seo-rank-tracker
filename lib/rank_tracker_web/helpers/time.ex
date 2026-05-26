defmodule RankTrackerWeb.Helpers.Time do
  def format_time(nil, _timezone, _format), do: ""

  def format_time(datetime, timezone, format \\ "%m/%d %H:%M") do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, shifted} -> Calendar.strftime(shifted, format)
      _ -> Calendar.strftime(datetime, format)
    end
  end
end
