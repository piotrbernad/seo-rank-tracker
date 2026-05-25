defmodule RankTrackerWeb.PageController do
  use RankTrackerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
