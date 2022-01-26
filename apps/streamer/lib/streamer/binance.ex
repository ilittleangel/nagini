defmodule Streamer.Binance do
  use WebSockex

  @stream_endpoint "wss://stream.binance.com:9443/ws/"

  def start_link(symbol) do
    symbol = String.downcase(symbol)
    url = "#{@stream_endpoint}#{symbol}@trade"
    WebSockex.start_link(url, __MODULE__, nil)
  end

  def handle_frame({type, msg}, state) do
    IO.puts("Received Message - Type: #{inspect type} -- Message: #{inspect msg}")
    {:ok, state}
  end
end
