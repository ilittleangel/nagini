defmodule Streamer.Binance do
  use WebSockex
  require Logger

  @stream_endpoint "wss://stream.binance.com:9443/ws/"

  def start_link(symbol) do
    symbol = String.downcase(symbol)
    url = "#{@stream_endpoint}#{symbol}@trade"
    WebSockex.start_link(url, __MODULE__, nil)
  end

  def handle_frame({_type, msg}, state) do
    case Jason.decode(msg) do
      {:ok, event} -> process_event(event)
      {:error, _} -> Logger.error("Unable to parse msg: #{msg}")
    end

    {:ok, state}
  end

  defp process_event(event) do
    case event do
      %{"e" => "trade"} ->
        trade_event = %Streamer.Binance.TradeEvent{
          :event_type         => event["e"],
          :event_time         => event["E"],
          :symbol             => event["s"],
          :trade_id           => event["t"],
          :price              => event["p"],
          :quantity           => event["q"],
          :buyer_order_id     => event["b"],
          :seller_order_id    => event["a"],
          :trade_time         => event["T"],
          :buyer_market_maker => event["m"]
        }
        Logger.debug("Trade event received #{trade_event.symbol}@#{trade_event.price}")

      _ ->
        Logger.debug("Other event received #{event}")
    end
  end
end
