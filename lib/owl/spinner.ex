defmodule Owl.Spinner do
  @moduledoc ~S"""
  A spinner widget.

  Simply run any long-running task using `run/2`:

      Owl.Spinner.run(
        fn -> Process.sleep(5_000) end,
        labels: [ok: "Done", error: "Failed", processing: "Please wait..."]
      )

  Multiple spinners can be run simultaneously:

      long_running_tasks =
        Enum.map([9000, 8000, 4000, 6000], fn delay ->
          fn -> Process.sleep(delay) end
        end)

      long_running_tasks
      |> Task.async_stream(&Owl.Spinner.run/1, timeout: :infinity)
      |> Stream.run()

  Multiline frames are supported as well:

      Owl.Spinner.run(fn -> Process.sleep(5_000) end,
        frames: [
          processing: [
            "╔════╤╤╤╤════╗\n║    │││ \\   ║\n║    │││  O  ║\n║    OOO     ║",
            "╔════╤╤╤╤════╗\n║    ││││    ║\n║    ││││    ║\n║    OOOO    ║",
            "╔════╤╤╤╤════╗\n║   / │││    ║\n║  O  │││    ║\n║     OOO    ║",
            "╔════╤╤╤╤════╗\n║    ││││    ║\n║    ││││    ║\n║    OOOO    ║"
          ]
        ]
      )

  ### Where can I get alternative frames?

  * https://github.com/blackode/elixir_cli_spinners/blob/master/lib/cli_spinners/spinners.ex
  * https://www.google.com/search?q=ascii+spinners
  """
  use GenServer, restart: :transient
  @type id :: any()
  @type label :: Owl.Data.t()
  @type frame :: Owl.Data.t()

  @default_processing_frames ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

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
  Runs a spinner during execution of `process_function` and returns its result.

  The spinner is started, and automatically stopped after the function returns, regardless if there was an error when executing the function.
  It is a wrapper around `start/1` and `stop/1`. The only downside of `run/2` is that it is not possible to update
  a label while `process_function` is executing.

  If function returns `:ok` or `{:ok, value}` then spinner will be stopped with `:ok` resolution.

  If function returns `:error` or `{:error, reason}` then spinner will be stopped with `:error` resolution.

  ## Options

  * `:refresh_every` - period of changing frames. Defaults to `100`.
  * `:frames` - allows to set frames for different states of spinner:
    * `:processing` - list of frames which are rendered until spinner is stopped.
    Defaults to `#{inspect(@default_processing_frames)}`.
    * `:ok` - frame that is rendered when spinner is stopped with `:ok` resolution.
    Defaults to `Owl.Data.tag("✔", :green)`.
    * `:error` - frame that is rendered when spinner is stopped with `:error` resolution.
    Defaults to `Owl.Data.tag("✖", :red)`.
  * `:labels` - allows to set labels for different states of spinner:
    * `:processing` - label that is rendered during processing. Cannot be changed during execution of `process_function`.
    Defaults to `nil`.
    * `:ok` - label that is rendered when spinner is stopped with `:ok` resolution. A function with arity 1 can be
    passed in order to format a label based on result of `process_function`.
    Defaults to `nil`.
    * `:error` - label that is rendered when spinner is stopped with `:error` resolution. A function with arity 1
    can be passed in order to format a label based on result of `process_function`.
    Defaults to `nil`.
  * `:live_screen_server` - a reference to `Owl.LiveScreen` server. Defaults to `Owl.LiveScreen`.

  ## Examples

      Owl.Spinner.run(fn -> Process.sleep(5_000) end)
      => :ok

      Owl.Spinner.run(fn -> Process.sleep(5_000) end,
        frames: [
          # an ASCII fish going back and forth
          processing: [
            ">))'>",
            "    >))'>",
            "        >))'>",
            "    <'((<",
            "<'((<"
          ]
        ]
      )
      => :ok

      Owl.Spinner.run(
        fn ->
          Process.sleep(5_000)
          {:error, :oops}
        end,
        labels: [
          error: fn reason -> "Failed: \#{inspect(reason)}" end,
          processing: "Processing..."
        ]
      )
      => {:error, :oops}
  """
  @spec run(process_function :: (-> :ok | :error | {:ok, value} | {:error, reason}),
          refresh_every: non_neg_integer(),
          frames: [ok: frame(), error: frame(), processing: [frame()]],
          labels: [
            ok: label() | (nil | value -> label() | nil) | nil,
            error: label() | (nil | reason -> label()) | nil,
            processing: label() | nil
          ],
          live_screen_server: GenServer.server()
        ) :: :ok | :error | {:ok, value} | {:error, reason}
        when value: any, reason: any
  def run(process_function, opts \\ []) do
    id = make_ref()

    with {:ok, _server_pid} <-
           start(
             opts
             |> Keyword.take([:refresh_every, :live_screen_server, :frames, :labels])
             |> Keyword.update(:labels, [], fn labels -> Keyword.take(labels, [:processing]) end)
             |> Keyword.put(:id, id)
           ) do
      try do
        result = process_function.()
        labels = Keyword.get(opts, :labels, [])

        case result do
          :ok ->
            label = maybe_get_lazy_label(labels, :ok, nil)
            stop(id: id, resolution: :ok, label: label)

          {:ok, value} ->
            label = maybe_get_lazy_label(labels, :ok, value)
            stop(id: id, resolution: :ok, label: label)

          :error ->
            label = maybe_get_lazy_label(labels, :error, nil)
            stop(id: id, resolution: :error, label: label)

          {:error, reason} ->
            label = maybe_get_lazy_label(labels, :error, reason)
            stop(id: id, resolution: :error, label: label)
        end

        result
      rescue
        e ->
          stop(id: id, resolution: :error)
          reraise(e, __STACKTRACE__)
      end
    end
  end

  defp maybe_get_lazy_label(labels, key, value) do
    case labels[key] do
      callback when is_function(callback, 1) -> callback.(value)
      label -> label
    end
  end

  @doc """
  Starts a new spinner.

  Must be stopped manually by calling `stop/1`.

  ## Options

  * `:id` - an id of the spinner. Required.
  * `:refresh_every` - period of changing frames. Defaults to `100`.
  * `:frames` - allows to set frames for different states of spinner:
    * `:processing` - list of frames which are rendered until spinner is stopped.
    Defaults to `#{inspect(@default_processing_frames)}`.
    * `:ok` - frame that is rendered when spinner is stopped with `:ok` resolution.
    Defaults to `Owl.Data.tag("✔", :green)`.
    * `:error` - frame that is rendered when spinner is stopped with `:error` resolution.
    Defaults to `Owl.Data.tag("✖", :red)`.
  * `:labels` - allows to set labels for different states of spinner:
    * `:processing` - label that is rendered during processing. Can be changed with `update_label/1`.
    Defaults to `nil`.
    * `:ok` - label that is rendered when spinner is stopped with `:ok` resolution.
    Defaults to `nil`.
    * `:error` - label that is rendered when spinner is stopped with `:error` resolution.
    Defaults to `nil`.
  * `:live_screen_server` - a reference to `Owl.LiveScreen` server. Defaults to `Owl.LiveScreen`.

  ## Example

      Owl.Spinner.start(id: :my_spinner)
      Process.sleep(1000)
      Owl.Spinner.stop(id: :my_spinner, resolution: :ok)
  """
  @spec start(
          id: id(),
          frames: [ok: frame(), error: frame(), processing: [frame()]],
          labels: [ok: label() | nil, error: label() | nil, processing: label() | nil],
          refresh_every: non_neg_integer(),
          live_screen_server: GenServer.server()
        ) :: DynamicSupervisor.on_start_child()
  def start(opts) do
    DynamicSupervisor.start_child(Owl.WidgetsSupervisor, {__MODULE__, opts})
  end

  @doc """
  Updates a label of the running spinner.

  Overrides a value that is set for `:processing` state on start.

  ## Options

  * `:id` - an id of the spinner. Required.
  * `:label` - a new value of the label. Required.

  ## Example

      Owl.Spinner.start(id: :my_spinner)
      Owl.Spinner.update_label(id: :my_spinner, label: "Downloading files...")
      Process.sleep(1000)
      Owl.Spinner.update_label(id: :my_spinner, label: "Checking signatures...")
      Process.sleep(1000)
      Owl.Spinner.stop(id: :my_spinner, resolution: :ok, label: "Done")
  """
  @spec update_label(id: id(), label: label()) :: :ok
  def update_label(opts) do
    id = Keyword.fetch!(opts, :id)
    label = Keyword.fetch!(opts, :label)
    GenServer.cast({:via, Registry, {Owl.WidgetsRegistry, id}}, {:update_label, label})
  end

  @doc """
  Stops the spinner.

  ## Options

  * `:id` - an id of the spinner. Required.
  * `:resolution` - an atom `:ok` or `:error`. Determines frame and label for final rendering. Required.
  * `:label` - a label for final rendering. If not set, then values that are set on spinner start will be used.

  ## Example

      Owl.Spinner.stop(id: :my_spinner, resolution: :ok)
  """
  @spec stop(id: id(), resolution: :ok | :error, label: label()) :: :ok
  def stop(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.call({:via, Registry, {Owl.WidgetsRegistry, id}}, {:stop, opts})
  end

  @impl true
  def init(opts) do
    frames = Keyword.get(opts, :frames, [])

    processing_frames = Keyword.get(frames, :processing, @default_processing_frames)
    ok_frame = Keyword.get(frames, :ok, Owl.Data.tag("✔", :green))
    error_frame = Keyword.get(frames, :error, Owl.Data.tag("✖", :red))
    labels = Keyword.get(opts, :labels, [])
    ok_label = Keyword.get(labels, :ok)
    error_label = Keyword.get(labels, :error)
    processing_label = Keyword.get(labels, :processing)
    refresh_every = Keyword.get(opts, :refresh_every, 100)

    live_screen_server = opts[:live_screen_server] || Owl.LiveScreen
    live_screen_ref = make_ref()

    {current_frame, next_processing_frames} = rotate_frames(processing_frames)

    Owl.LiveScreen.add_block(live_screen_server, live_screen_ref,
      state: %{frame: current_frame, label: processing_label},
      render: &render/1
    )

    Process.send_after(self(), :tick, refresh_every)

    {:ok,
     %{
       refresh_every: refresh_every,
       live_screen_ref: live_screen_ref,
       live_screen_server: live_screen_server,
       processing_frames: next_processing_frames,
       ok_frame: ok_frame,
       error_frame: error_frame,
       ok_label: ok_label,
       error_label: error_label,
       processing_label: processing_label
     }}
  end

  @impl true
  def handle_cast({:update_label, new_value}, state) do
    {:noreply, %{state | processing_label: new_value}}
  end

  @impl true
  def handle_call({:stop, opts}, _from, state) do
    {frame, label} =
      case Keyword.fetch!(opts, :resolution) do
        :ok -> {state.ok_frame, Keyword.get(opts, :label, state.ok_label)}
        :error -> {state.error_frame, Keyword.get(opts, :label, state.error_label)}
      end

    Owl.LiveScreen.update(state.live_screen_server, state.live_screen_ref, %{
      frame: frame,
      label: label
    })

    Owl.LiveScreen.await_render(state.live_screen_server)

    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    {current_frame, next_processing_frames} = rotate_frames(state.processing_frames)

    Owl.LiveScreen.update(state.live_screen_server, state.live_screen_ref, %{
      frame: current_frame,
      label: state.processing_label
    })

    Process.send_after(self(), :tick, state.refresh_every)

    {:noreply, %{state | processing_frames: next_processing_frames}}
  end

  defp rotate_frames([head | rest]) do
    {head, rest ++ [head]}
  end

  defp render(%{frame: frame, label: nil}), do: frame
  defp render(%{frame: frame, label: label}), do: [frame, " ", label]
end
