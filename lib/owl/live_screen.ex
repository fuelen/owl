defmodule Owl.LiveScreen do
  @moduledoc ~S"""
  A server that handles live updates in terminal.

  It partially implements [The Erlang I/O Protocol](https://www.erlang.org/doc/apps/stdlib/io_protocol.html),
  so it is possible to use `Owl.LiveScreen` as an I/O-device in `Logger`
  and functions like `Owl.IO.puts/2`, `IO.puts/2`. When used as I/O-device, then output is printed above dynamic blocks.

  ## Example

      require Logger
      :ok = :logger.remove_handler(:default)

      :ok =
        :logger.add_handler(:default, :logger_std_h, %{
          config: %{type: {:device, Owl.LiveScreen}},
          formatter: Logger.Formatter.new()
        })

      Owl.LiveScreen.add_block(:dependency,
        state: :init,
        render: fn
          :init -> "init..."
          dependency -> ["dependency: ", Owl.Data.tag(dependency, :yellow)]
        end
      )

      Owl.LiveScreen.add_block(:compiling,
        render: fn
          :init -> "init..."
          filename -> ["compiling: ", Owl.Data.tag(to_string(filename), :cyan)]
        end
      )

      ["ecto", "phoenix", "ex_doc", "broadway"]
      |> Enum.each(fn dependency ->
        Owl.LiveScreen.update(:dependency, dependency)

        1..5
        |> Enum.map(&"filename#{&1}.ex")
        |> Enum.each(fn filename ->
          Owl.LiveScreen.update(:compiling, filename)
          Process.sleep(1000)
          Logger.debug("#{filename} compiled for dependency #{dependency}")
        end)
      end)
  """
  use GenServer

  @type block_id :: any()
  @type add_block_option :: {:state, any()} | {:render, (block_state :: any() -> Owl.Data.t())}
  @type start_option ::
          {:name, GenServer.name()}
          | {:refresh_every, pos_integer()}
          | {:terminal_width, pos_integer() | :auto}
          | {:device, IO.device()}

  @refresh_every_default 60

  @doc """
  Starts a server.

  Server is started automatically by `:owl` application as a named process.

  ## Options

  * `:name` - used for name registration as described in the "Name
  registration" section in the documentation for `GenServer`. Defaults to `Owl.LiveScreen`
  * `:refresh_every` - a period of refreshing a screen in milliseconds. Defaults to #{@refresh_every_default}.
  * `:terminal_width` - a width of terminal in symbols. Defaults to `:auto`, which gets value from `Owl.IO.columns/1`.
  * `:device` - an I/O device. Defaults to `:stdio`.
  If terminal is not available, then the server won't be started.
  """
  @spec start_link([start_option()]) :: GenServer.on_start()
  def start_link(opts) do
    server_options = Keyword.take(opts, [:name])

    GenServer.start_link(__MODULE__, opts, server_options)
  end

  @doc """
  Allows updating the device of the LiveScreen.

  This is useful for example when using the Erlang SSH console.

  ## Example
      group_leader = Process.group_leader()

      Owl.LiveScreen.set_device(group_leader)
  """
  @spec set_device(GenServer.server(), IO.device()) :: :ok
  def set_device(server \\ __MODULE__, new_device) do
    GenServer.call(server, {:set_device, new_device})
  end

  @doc """
  Returns the current device used by the LiveScreen.
  """
  @spec get_device(GenServer.server()) :: IO.device()
  def get_device(server \\ __MODULE__) do
    GenServer.call(server, :get_device)
  end

  @doc """
  Redirects output from `:stdio` to `#{inspect(__MODULE__)}`.

  ## Example

      Owl.ProgressBar.start(id: :users, label: "Creating users", total: 100)

      Owl.LiveScreen.capture_stdio(fn ->
        Enum.each(1..100, fn i ->
          Process.sleep(10)
          Owl.ProgressBar.inc(id: :users)
          # Output from next call will be printed above progress bar
          IO.inspect([:test, i])
        end)
      end)

      Owl.LiveScreen.await_render()

  """
  @spec capture_stdio(GenServer.server(), (-> result)) :: result when result: any
  def capture_stdio(server \\ __MODULE__, callback) when is_function(callback, 0) do
    original_gl = Process.group_leader()

    live_screen_server_pid =
      case GenServer.whereis(server) do
        pid when is_pid(pid) -> pid
      end

    Process.group_leader(self(), live_screen_server_pid)

    try do
      Process.group_leader(self(), live_screen_server_pid)
      callback.()
    after
      Process.group_leader(self(), original_gl)
    end
  end

  @doc """
  Adds a sticky block to the bottom of the screen that can be updated using `update/3`.

  ## Options

  * `:render` - a function that accepts `state` and returns a view of the block. Defaults to `Function.identity/1`, which
  means that state has to have type `t:Owl.Data.t/0`.
  * `:state` - initial state of the block. Defaults to `nil`.

  ## Example

      Owl.LiveScreen.add_block(:footer, state: "starting...")
      # which is equivalent to
      Owl.LiveScreen.add_block(:footer, render: fn
        nil -> "starting..."
        data -> data
      end)
  """
  @spec add_block(GenServer.server(), block_id(), [add_block_option()]) :: :ok
  def add_block(server \\ __MODULE__, block_id, opts) when is_list(opts) do
    GenServer.cast(server, {:add_block, block_id, opts})
  end

  @doc """
  Updates a state of the block for using it in the next render iteration.

  ## Example

      Owl.LiveScreen.add_block(:footer, state: "starting...")
      Process.sleep(1000)
      Owl.LiveScreen.update(:footer, "...almost done...")
      Process.sleep(1000)
      Owl.LiveScreen.update(:footer, "done!!!")

  """
  @spec update(GenServer.server(), block_id(), block_state :: any()) :: :ok
  def update(server \\ __MODULE__, block_id, block_state) do
    GenServer.cast(server, {:update, block_id, block_state})
  end

  @doc """
  Awaits for next rendering.

  This is useful when you want to ensure that last published state is rendered on the screen.

  ## Example

      Owl.LiveScreen.add_block(:status, state: "starting...")
      Owl.LiveScreen.update(:status, "done!")
      Owl.LiveScreen.await_render()
  """
  @spec await_render(GenServer.server()) :: :ok
  def await_render(server \\ __MODULE__) do
    GenServer.cast(server, {:notify_on_next_render, self()})

    receive do
      :rendered -> :ok
    end
  end

  @doc """
  Renders data in buffer and detaches blocks.
  """
  @spec flush(GenServer.server()) :: :ok
  def flush(server \\ __MODULE__) do
    GenServer.call(server, :flush)
  end

  @doc """
  Renders data in buffer and terminates a server.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server \\ __MODULE__) do
    GenServer.stop(server)
  end

  # we define child_spec just to disable doc
  @doc false
  def child_spec(init_arg) do
    super(init_arg)
  end

  @impl true
  def init(opts) do
    refresh_every = opts[:refresh_every] || @refresh_every_default

    terminal_width = opts[:terminal_width] || :auto
    device = opts[:device] || :stdio

    terminal_device? = not is_nil(get_terminal_width(terminal_width, device))

    if terminal_device? do
      {:ok, init_state(terminal_width, refresh_every, device)}
    else
      :ignore
    end
  end

  defp init_state(terminal_width, refresh_every, device) do
    %{
      device: device,
      timer_ref: nil,
      notify_on_next_render: [],
      terminal_width: terminal_width,
      refresh_every: refresh_every,
      put_above_blocks: [],
      put_above_blocks_performed?: false,
      put_above_blocks_sources: [],
      content: %{},
      block_states: %{},
      render_functions: %{},
      rendered_blocks: [],
      rendered_content_height: %{},
      blocks_to_add: []
    }
  end

  @impl true
  def terminate(_, state) do
    render(state)
  end

  @impl true
  def handle_cast({:add_block, block_id, opts}, state) do
    block_state = opts[:state]
    render = opts[:render] || (&Function.identity/1)

    # initiate rendering when adding first block
    timer_ref =
      if is_nil(state.timer_ref) and empty_blocks_list?(state) do
        Process.send_after(self(), :render, state.refresh_every)
      else
        state.timer_ref
      end

    {:noreply,
     %{
       state
       | blocks_to_add: state.blocks_to_add ++ [block_id],
         block_states: Map.put(state.block_states, block_id, block_state),
         render_functions: Map.put(state.render_functions, block_id, render),
         timer_ref: timer_ref
     }}
  end

  def handle_cast({:notify_on_next_render, pid}, state) do
    empty_buffer? =
      state.put_above_blocks == [] and is_nil(state.timer_ref) and empty_blocks_list?(state)

    if empty_buffer? do
      send(pid, :rendered)
      {:noreply, state}
    else
      {:noreply, %{state | notify_on_next_render: [pid | state.notify_on_next_render]}}
    end
  end

  def handle_cast({:update, block_id, block_state}, state) do
    {:noreply,
     %{
       state
       | block_states: Map.put(state.block_states, block_id, block_state)
     }}
  end

  @impl true
  def handle_call({:set_device, new_device}, _, state) do
    state = render(state)

    state = init_state(state.terminal_width, state.refresh_every, new_device)

    {:reply, :ok, state}
  end

  def handle_call(:get_device, _, state) do
    {:reply, state.device, state}
  end

  def handle_call(:flush, _, state) do
    state = render(state)

    state = init_state(state.terminal_width, state.refresh_every, state.device)

    {:reply, :ok, state}
  end

  # for private usage without public interface
  def handle_call(:render, _, state) do
    state = render(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:render, state) do
    state = render(state)

    timer_ref =
      if not is_nil(state.timer_ref) and not empty_blocks_list?(state) do
        case Process.read_timer(state.timer_ref) do
          false ->
            :noop

          _ms ->
            Process.cancel_timer(state.timer_ref)
        end

        Process.send_after(self(), :render, state.refresh_every)
      end

    {:noreply, %{state | timer_ref: timer_ref}}
  end

  def handle_info({:io_request, from, reply_as, req}, state) do
    state = io_request(from, reply_as, req, state)
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp io_request(from, reply_as, {:put_chars, chars}, state) do
    put_chars(from, reply_as, chars, state)
  end

  defp io_request(from, reply_as, {:put_chars, mod, fun, args}, state) do
    put_chars(from, reply_as, apply(mod, fun, args), state)
  end

  defp io_request(from, reply_as, {:put_chars, _encoding, chars}, state) do
    put_chars(from, reply_as, chars, state)
  end

  defp io_request(from, reply_as, {:put_chars, _encoding, mod, fun, args}, state) do
    put_chars(from, reply_as, apply(mod, fun, args), state)
  end

  defp io_request(from, reply_as, req, state) do
    {reply, state} = io_request(req, state)
    io_reply(from, reply_as, reply)
    state
  end

  defp io_request({:get_chars, _prompt, _count}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_chars, _encoding, _prompt, _count}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_line, _prompt}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_line, _encoding, _prompt}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_until, _prompt, _mod, _fun, _args}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_until, _encoding, _prompt, _mod, _fun, _args}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_password, _encoding}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:setopts, _opts}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request(:getopts, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request({:get_geometry, :columns}, state) do
    {Owl.IO.columns(state.device) || {:error, :enotsup}, state}
  end

  defp io_request({:get_geometry, :rows}, state) do
    {Owl.IO.rows(state.device) || {:error, :enotsup}, state}
  end

  defp io_request({:requests, _reqs}, state) do
    {{:error, :enotsup}, state}
  end

  defp io_request(_, state) do
    {{:error, :request}, state}
  end

  defp put_chars(from, reply_as, chars, state) do
    send(self(), :render)

    %{
      state
      | put_above_blocks: [chars | state.put_above_blocks],
        put_above_blocks_sources: [{from, reply_as} | state.put_above_blocks_sources]
    }
  end

  defp io_reply(from, reply_as, reply) do
    send(from, {:io_reply, reply_as, reply})
  end

  defp get_terminal_width(:auto, device), do: Owl.IO.columns(device)
  defp get_terminal_width(number, _device) when is_integer(number), do: number

  defp render(state) do
    terminal_width = get_terminal_width(state.terminal_width, state.device)

    {state, render_above_data, io_reply} = render_above(state)

    {state, render_updated_blocks_data} =
      rerender_updated_blocks(state, render_above_data != [], terminal_width)

    {state, render_added_blocks_data} = render_added_blocks(state, terminal_width)

    data =
      [
        render_above_data,
        render_updated_blocks_data,
        render_added_blocks_data
      ]
      |> Enum.reject(&(&1 == []))
      |> Owl.Data.unlines()

    if data != [] do
      Owl.IO.puts(data, state.device)
      io_reply.()
    end

    for pid <- state.notify_on_next_render do
      send(pid, :rendered)
    end

    %{state | block_states: %{}, notify_on_next_render: []}
  end

  defp get_content(state, block_id, terminal_width) do
    case Map.fetch(state.block_states, block_id) do
      {:ok, block_state} ->
        block_content = state.render_functions[block_id].(block_state)

        lines =
          block_content
          |> Owl.Data.lines()
          |> Enum.flat_map(fn
            [] -> [[]]
            line -> Owl.Data.chunk_every(line, terminal_width)
          end)

        {
          lines
          |> Enum.map(&[IO.ANSI.clear_line(), &1])
          |> Owl.Data.unlines(),
          length(lines)
        }

      :error ->
        {state.content[block_id], state.rendered_content_height[block_id]}
    end
  end

  defp noop, do: :noop

  defp render_above(%{put_above_blocks: []} = state), do: {state, [], &noop/0}

  defp render_above(%{put_above_blocks: put_above_blocks} = state) do
    blocks_height = Enum.sum(Map.values(state.rendered_content_height))
    data = Enum.reverse(put_above_blocks)

    cursor_up =
      if state.put_above_blocks_performed? do
        blocks_height + 1
      else
        blocks_height
      end

    data =
      if cursor_up == 0 do
        data
      else
        [cursor_up_and_clear_lines(cursor_up), data]
      end

    {%{
       state
       | put_above_blocks: [],
         put_above_blocks_performed?: true,
         put_above_blocks_sources: []
     }, data,
     fn ->
       state.put_above_blocks_sources
       |> Enum.reverse()
       |> Enum.each(fn {from, reply_as} ->
         io_reply(from, reply_as, :ok)
       end)
     end}
  end

  defp cursor_up_and_clear_lines(n) do
    List.duplicate([IO.ANSI.cursor_up(1), IO.ANSI.clear_line()], n)
  end

  defp rerender_updated_blocks(state, rendered_above?, terminal_width) do
    blocks_to_replace = Map.keys(state.block_states) -- state.blocks_to_add

    if not rendered_above? and Enum.empty?(blocks_to_replace) do
      {state, []}
    else
      {content_blocks, %{total_height: total_height, state: state, next_offset: return_to_end}} =
        state.rendered_blocks
        |> Enum.flat_map_reduce(
          %{total_height: 0, next_offset: 0, force_rerender?: rendered_above?, state: state},
          fn block_id,
             %{
               total_height: total_height,
               next_offset: next_offset,
               state: state,
               force_rerender?: force_rerender?
             } ->
            if force_rerender? or block_id in blocks_to_replace do
              {block_content, height} = get_content(state, block_id, terminal_width)

              max_height = max(height, state.rendered_content_height[block_id])

              block_content = [
                block_content,
                List.duplicate(["\n", IO.ANSI.clear_line()], max_height - height)
              ]

              {[%{offset: next_offset, content: block_content}],
               %{
                 total_height: total_height + state.rendered_content_height[block_id],
                 next_offset: 0,
                 force_rerender?:
                   force_rerender? || height > state.rendered_content_height[block_id],
                 state: %{
                   state
                   | rendered_content_height:
                       Map.put(state.rendered_content_height, block_id, max_height),
                     content: Map.put(state.content, block_id, block_content)
                 }
               }}
            else
              height = state.rendered_content_height[block_id]

              {[],
               %{
                 total_height: total_height + height,
                 next_offset: next_offset + height,
                 state: state,
                 force_rerender?: force_rerender?
               }}
            end
          end
        )

      if content_blocks == [] do
        {state, []}
      else
        data = [
          if(rendered_above? or total_height == 0, do: [], else: IO.ANSI.cursor_up(total_height)),
          content_blocks
          |> Enum.map(fn
            %{offset: 0, content: content} -> content
            %{offset: offset, content: content} -> [IO.ANSI.cursor_down(offset), content]
          end)
          |> Owl.Data.unlines(),
          if(return_to_end == 0, do: [], else: IO.ANSI.cursor_down(return_to_end))
        ]

        {state, data}
      end
    end
  end

  defp render_added_blocks(%{blocks_to_add: []} = state, _terminal_width), do: {state, []}

  defp render_added_blocks(state, terminal_width) do
    {content_blocks, state} =
      Enum.map_reduce(state.blocks_to_add, state, fn block_id, state ->
        {block_content, height} = get_content(state, block_id, terminal_width)

        {block_content,
         %{
           state
           | rendered_content_height: Map.put(state.rendered_content_height, block_id, height),
             content: Map.put(state.content, block_id, block_content)
         }}
      end)

    state = %{
      state
      | blocks_to_add: [],
        rendered_blocks: state.rendered_blocks ++ state.blocks_to_add
    }

    {state, Owl.Data.unlines(content_blocks)}
  end

  defp empty_blocks_list?(state) do
    state.rendered_blocks == [] and state.blocks_to_add == []
  end
end
