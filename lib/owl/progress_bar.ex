defmodule Owl.ProgressBar do
  @moduledoc ~S"""
  A live progress bar widget.

  ## Single bar

      Owl.ProgressBar.start(id: :users, label: "Creating users", total: 1000)

      Enum.each(1..1000, fn _ ->
        Process.sleep(10)
        Owl.ProgressBar.inc(id: :users)
      end)

      Owl.LiveScreen.await_render()

  ## Multiple bars

      1..10
      |> Enum.map(fn index ->
        Task.async(fn ->
          range = 1..Enum.random(100..500)

          label = "Demo Progress ##{index}"

          Owl.ProgressBar.start(
            id: {:demo, index},
            label: label,
            total: range.last,
            timer: true,
            bar_width_ratio: 0.3,
            filled_symbol: "#",
            partial_symbols: []
          )

          Enum.each(range, fn _ ->
            Process.sleep(Enum.random(10..50))
            Owl.ProgressBar.inc(id: {:demo, index})
          end)
        end)
      end)
      |> Task.await_many(:infinity)

      Owl.LiveScreen.await_render()
  """
  use GenServer, restart: :transient

  @type id :: any()

  @tick_interval_ms 100

  @doc false
  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: {:via, Registry, {Owl.WidgetsRegistry, id}})
  end

  # we define child_spec just to disable doc
  @doc false
  def child_spec(init_arg) do
    super(init_arg)
  end

  @doc """
  Starts a progress bar on `Owl.LiveScreen`.

  ## Options

  * `:id` - an id of the progress bar. Required.
  * `:label` - a label of the progress bar. Required.
  * `:total` - a total value. Required.
  * `:current` - a current value. Defaults to `0`.
  * `:bar_width_ratio` - a bar width ratio. Defaults to 0.7.
  * `:timer` - set to `true` to launch a timer and display it before the bar in format `MM:SS`. Defaults to `false`.
  * `:absolute_values` - set to `true` to show absolute values before the bar in format `current/total`. Defaults to `false`.
  * `:start_symbol` - a symbol that is rendered at the beginning of the progress bar. Defaults to `"["`.
  * `:end_symbol` - a symbol that rendered at the end of the progress bar. Defaults to `"]"`.
  * `:filled_symbol` - a symbol that use used when `current` value is big enough to fill the cell. Defaults to `"≡"`
  * `:partial_symbols` - a list of symbols that are used when `current` value is too small to render
  `filled_symbol`. Defaults to `["-", "="]`.
  * `:empty_symbol` - an empty symbol. Defaults to `" "`.
  * `:screen_width` - a width of output data. Defaults to width of the terminal or 80 symbols, if a terminal is not available.
  * `:live_screen_server` - a reference to `Owl.LiveScreen` server. Defaults to `Owl.LiveScreen`.
  """
  @spec start(
          label: Owl.Data.t(),
          id: id(),
          total: pos_integer(),
          timer: boolean(),
          absolute_values: boolean(),
          current: non_neg_integer(),
          bar_width_ratio: nil | float(),
          start_symbol: Owl.Data.t(),
          end_symbol: Owl.Data.t(),
          filled_symbol: Owl.Data.t(),
          partial_symbols: [Owl.Data.t()],
          empty_symbol: Owl.Data.t(),
          screen_width: pos_integer(),
          live_screen_server: GenServer.server()
        ) :: DynamicSupervisor.on_start_child()
  def start(opts) do
    DynamicSupervisor.start_child(Owl.WidgetsSupervisor, {__MODULE__, opts})
  end

  @doc """
  Increases `current` value by `step`.

  When `current` value becomes equal to `total`, then progress bar terminates.

  ## Options

  * `:id` - an required identifier of the progress bar.
  * `:step` - a value by which `current` value should be increased. Defaults to 1.

  ## Examples

      Owl.ProgressBar.inc(id: "Creating users")

      Owl.ProgressBar.inc(id: "Creating users", step: 10)
  """
  @spec inc(id: id(), step: integer()) :: :ok
  def inc(opts \\ []) do
    step = opts[:step] || 1
    id = Keyword.fetch!(opts, :id)
    GenServer.cast({:via, Registry, {Owl.WidgetsRegistry, id}}, {:inc, step})
  end

  @impl true
  def init(opts) do
    total = Keyword.fetch!(opts, :total)
    label = Keyword.fetch!(opts, :label)
    timer = Keyword.get(opts, :timer, false)
    absolute_values = Keyword.get(opts, :absolute_values, false)
    filled_symbol = opts[:filled_symbol] || "≡"
    partial_symbols = opts[:partial_symbols] || ["-", "="]
    empty_symbol = opts[:empty_symbol] || " "
    start_symbol = opts[:start_symbol] || "["
    end_symbol = opts[:end_symbol] || "]"
    screen_width = opts[:screen_width]
    current = opts[:current] || 0
    bar_width_ratio = opts[:bar_width_ratio] || 0.7
    live_screen_server = opts[:live_screen_server] || Owl.LiveScreen

    start_time =
      if timer do
        Process.send_after(self(), :tick, @tick_interval_ms)
        System.monotonic_time(:millisecond)
      end

    live_screen_ref = make_ref()

    state = %{
      live_screen_ref: live_screen_ref,
      live_screen_server: live_screen_server,
      bar_width_ratio: bar_width_ratio,
      total: total,
      label: label,
      start_time: start_time,
      current: current,
      screen_width: screen_width,
      start_symbol: start_symbol,
      end_symbol: end_symbol,
      empty_symbol: empty_symbol,
      filled_symbol: filled_symbol,
      partial_symbols: partial_symbols,
      absolute_values: absolute_values
    }

    Owl.LiveScreen.add_block(live_screen_server, live_screen_ref,
      state: state,
      render: &render/1
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:inc, step}, state) do
    state = %{state | current: state.current + step}
    Owl.LiveScreen.update(state.live_screen_server, state.live_screen_ref, state)

    if state.current >= state.total do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    if state.current < state.total do
      Process.send_after(self(), :tick, @tick_interval_ms)
      Owl.LiveScreen.update(state.live_screen_server, state.live_screen_ref, state)
    end

    {:noreply, state}
  end

  defp format_time(milliseconds) do
    ss =
      (rem(milliseconds, 60_000) / 1000)
      |> Float.round(1)
      |> to_string()
      |> String.pad_leading(4, "0")

    mm =
      milliseconds
      |> div(60_000)
      |> to_string()
      |> String.pad_leading(2, "0")

    "#{mm}:#{ss}"
  end

  @doc """
  Renders a progress bar that can be consumed by `Owl.IO.puts/2`.

  Used as a callback for blocks in `Owl.LiveScreen`.

  ## Examples

      iex> Owl.ProgressBar.render(%{
      ...>   label: "Demo",
      ...>   total: 200,
      ...>   current: 60,
      ...>   bar_width_ratio: 0.7,
      ...>   start_symbol: "[",
      ...>   end_symbol: "]",
      ...>   filled_symbol: "#",
      ...>   partial_symbols: [],
      ...>   empty_symbol: ".",
      ...>   screen_width: 40
      ...> }) |> to_string()
      "Demo      [######.................]  30%"

      iex> Owl.ProgressBar.render(%{
      ...>   label: "Demo",
      ...>   total: 200,
      ...>   current: 8,
      ...>   bar_width_ratio: 0.2,
      ...>   start_symbol: "|",
      ...>   absolute_values: true,
      ...>   end_symbol: "|",
      ...>   filled_symbol: "█",
      ...>   partial_symbols: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"],
      ...>   empty_symbol: " ",
      ...>   screen_width: 40,
      ...>   start_time: -576460748012758993,
      ...>   current_time: -576460748012729828
      ...> }) |> to_string()
      "Demo         8/200 00:29.2 |▎     |   4%"

      iex> Owl.ProgressBar.render(%{
      ...>   label: "Demo",
      ...>   total: 200,
      ...>   current: 8,
      ...>   bar_width_ratio: 0.7,
      ...>   start_symbol: "[",
      ...>   end_symbol: "]",
      ...>   filled_symbol: Owl.Data.tag("≡", :cyan),
      ...>   partial_symbols: [Owl.Data.tag("-", :green), Owl.Data.tag("=", :blue)],
      ...>   empty_symbol: " ",
      ...>   screen_width: 40
      ...> })|> Owl.Data.to_chardata() |> to_string()
      "Demo      [\e[34m=\e[39m                      ]   4%\e[0m"

      iex> Owl.ProgressBar.render(%{
      ...>   label: "Demo",
      ...>   total: 200,
      ...>   current: 60,
      ...>   bar_width_ratio: 0.95,
      ...>   start_symbol: "[",
      ...>   end_symbol: "]",
      ...>   filled_symbol: "#",
      ...>   partial_symbols: [],
      ...>   empty_symbol: ".",
      ...>   screen_width: 40
      ...> }) |> to_string()
      "D…[#########......................]  30%"

      iex> Owl.ProgressBar.render(%{
      ...>   label: "Demo",
      ...>   total: 200,
      ...>   current: 60,
      ...>   bar_width_ratio: 1,
      ...>   start_symbol: "[",
      ...>   end_symbol: "]",
      ...>   filled_symbol: "#",
      ...>   partial_symbols: [],
      ...>   empty_symbol: ".",
      ...>   screen_width: 40
      ...> }) |> to_string()
      "[#########........................]  30%"

  """
  @spec render(%{
          optional(:current_time) => nil | integer(),
          optional(:start_time) => nil | integer(),
          optional(:screen_width) => nil | pos_integer(),
          optional(:absolute_values) => nil | boolean(),
          bar_width_ratio: float(),
          label: Owl.Data.t(),
          total: pos_integer(),
          current: non_neg_integer(),
          start_symbol: Owl.Data.t(),
          end_symbol: Owl.Data.t(),
          filled_symbol: Owl.Data.t(),
          partial_symbols: [Owl.Data.t()],
          empty_symbol: Owl.Data.t()
        }) :: Owl.Data.t()
  def render(
        %{
          label: label,
          total: total,
          current: current,
          bar_width_ratio: bar_width_ratio,
          start_symbol: start_symbol,
          end_symbol: end_symbol,
          filled_symbol: filled_symbol,
          partial_symbols: partial_symbols,
          empty_symbol: empty_symbol
        } = params
      )
      when current >= 0 do
    screen_width = params[:screen_width] || Owl.IO.columns() || 80
    percentage_width = 5
    start_end_symbols_width = 2
    percentage = String.pad_leading("#{trunc(current / total * 100)}%", percentage_width)

    {elapsed_time_formatted, elapsed_time_formatted_width} =
      case params[:start_time] do
        nil ->
          {[], 0}

        start_time ->
          current_time = params[:current_time] || System.monotonic_time(:millisecond)
          elapsed_time = current_time - start_time
          # format_time width + 1 space = 8
          {[format_time(elapsed_time), " "], 8}
      end

    {absolute_values_formatted, absolute_values_formatted_width} =
      if params[:absolute_values] do
        total_string = to_string(total)
        total_width = String.length(total_string)

        {
          [String.pad_leading(to_string(current), total_width), "/", total_string, " "],
          # 2 = String.length("/" + " ")
          total_width * 2 + 2
        }
      else
        {[], 0}
      end

    infix = [absolute_values_formatted, elapsed_time_formatted]
    infix_width = elapsed_time_formatted_width + absolute_values_formatted_width

    # dynamic space = space for label, infix and bar.
    dynamic_space_width = screen_width - start_end_symbols_width - percentage_width

    bar_width = trunc(dynamic_space_width * bar_width_ratio)

    label_width = dynamic_space_width - bar_width - infix_width

    # Float.ceil(x, 2) is needed to handle numbers like 56.99999999999999
    progress = min(Float.ceil(current / (total / bar_width), 2), bar_width * 1.0)
    filled_blocks_integer = floor(progress)

    next_block =
      case partial_symbols do
        [] ->
          nil

        partial_symbols ->
          next_block_filling = Float.floor(progress - filled_blocks_integer, 2)

          if next_block_filling != 0 do
            idx = ceil(next_block_filling * length(partial_symbols)) - 1
            Enum.at(partial_symbols, idx)
          end
      end

    [
      pad_trailing_or_truncate(label, label_width),
      infix,
      start_symbol,
      List.duplicate(filled_symbol, filled_blocks_integer),
      case next_block do
        nil ->
          List.duplicate(empty_symbol, bar_width - filled_blocks_integer)

        next_block ->
          [next_block, List.duplicate(empty_symbol, bar_width - filled_blocks_integer - 1)]
      end,
      end_symbol,
      percentage
    ]
  end

  defp pad_trailing_or_truncate(_data, 0), do: []
  defp pad_trailing_or_truncate(_data, 1), do: "…"

  defp pad_trailing_or_truncate(data, length) when length > 0 do
    data_length = Owl.Data.length(data)

    cond do
      data_length > length ->
        data |> Owl.Data.slice(0, length - 1) |> List.wrap() |> Enum.concat(["…"])

      true ->
        [data, List.duplicate(" ", length - data_length)]
    end
  end
end
