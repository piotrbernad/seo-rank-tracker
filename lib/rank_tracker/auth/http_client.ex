defmodule RankTracker.Auth.HTTPClient do
  @spec request(:get | :post, String.t(), iodata(), [{String.t(), String.t()}]) ::
          {:ok, map()} | {:error, term()}
  def request(method, url, body, headers \\ []) do
    opts = [method: method, url: url, headers: headers]
    opts = if method == :post, do: Keyword.put(opts, :body, body), else: opts

    Req.new()
    |> Req.merge(opts)
    |> Req.request()
    |> case do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
