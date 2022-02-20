defmodule Naiver.Trader do
  use GenServer
  alias Streamer.Binance.TradeEvent
  alias Decimal
  require Logger

  defmodule State do
    @enforce_keys [:symbol, :profit_interval, :tick_size]
    defstruct [
      :symbol,
      :buy_order,
      :sell_order,
      :profit_interval, # what net profit % we would like to achieve when buying and selling an asset - single trade cycle
      :tick_size # it needs to be fetched from Binance and it’s used
      # to calculate a valid price Tick size differs between symbols
      # and it is the smallest acceptable price movement up or down.
      # For example in the physical world tick size for USD is a single
      # cent, you can’t sell something for $1.234, it’s either $1.23 or
      # $1.24 (a single cent difference between those is the tick size)
      # more info here (https://www.investopedia.com/terms/t/tick.asp)
    ]
  end

  def start_link(%{} = args) do
    GenServer.start_link(__MODULE__, args, name: :trader)
  end

  @impl GenServer
  def init(%{symbol: symbol, profit_interval: profit_interval}) do
    symbol = String.upcase(symbol)
    tick_size = fetch_tick_size(symbol)
    state = %State{symbol: symbol, profit_interval: profit_interval, tick_size: tick_size}

    Logger.info("Initializing new trader for #{symbol}")

    {:ok, state}
  end

  # first state: a new trader without any orders
  @impl GenServer
  def handle_cast(%TradeEvent{price: price}, %State{symbol: symbol, buy_order: nil} = state) do
    quantity = "100"

    Logger.info("Placing BUY order for #{symbol} @ #{price}, quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} = Binance.order_limit_buy(symbol, quantity, price, "GTC")

    {:noreply, %{state | buy_order: order}}
  end

  # second state: a trader with a buy order placed
  @impl GenServer
  def handle_cast(
    %TradeEvent{buyer_order_id: order_id, quantity: quantity},
    %State{
      symbol: symbol,
      buy_order: %Binance.OrderResponse{price: buy_price, order_id: order_id, orig_qty: quantity},
      profit_interval: profit_interval,
      tick_size: tick_size
    } = state) do

    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    Logger.info("Buy order filled, placing SELL order for " <> "#{symbol} @ #{sell_price}), quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} = Binance.order_limit_sell(symbol, quantity, sell_price, "GTC")

    {:noreply, %{state | sell_order: order}}
  end

  defp fetch_tick_size(symbol) do
    Binance.get_exchange_info()
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> Map.get("filters")
    |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
    |> Map.get("tickSize")
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    fee = "1.001"
    original_price = Decimal.mult(buy_price, fee)
    net_target_price = Decimal.mult(original_price, Decimal.add("1.0", profit_interval))
    gross_target_price = Decimal.mult(net_target_price, fee)
    Decimal.to_string(Decimal.mult(Decimal.div_int(gross_target_price, tick_size), tick_size), :normal)
  end

end
