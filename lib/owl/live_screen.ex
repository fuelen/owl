defmodule Owl.LiveScreen do
  use GenServer

  @doc false
  def start_link(opts) do
    server_options = Keyword.take(opts, [:name])

    GenServer.start_link(__MODULE__, opts, server_options)
  end

  def add_block(server \\ __MODULE__, block_id, params) do
    GenServer.cast(server, {:add_block, block_id, params})
  end

  def put_above(server \\ __MODULE__, message) do
    GenServer.cast(server, {:put_above, message})
  end

  def send(server \\ __MODULE__, block_id, message) do
    GenServer.cast(server, {:send, block_id, message})
  end

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
    refresh_every = opts[:refresh_every] || 100

    terminal_width = opts[:terminal_width] || :auto

    terminal_device? = not is_nil(get_terminal_width(terminal_width))

    if terminal_device? do
      {:ok,
       %{
         terminal_width: terminal_width,
         refresh_every: refresh_every,
         put_above: [],
         content: %{},
         messages: %{},
         handlers: %{},
         rendered_blocks: [],
         rendered_content_height: %{},
         blocks_to_add: []
       }}
    else
      :ignore
    end
  end

  @impl true
  def terminate(_, state) do
    render(state)
  end

  @impl true
  def handle_cast({:add_block, block_id, params}, state) do
    message = params[:message]
    handler = params[:handler] || (&Function.identity/1)

    # initiate rendering when adding first block
    if state.rendered_blocks == [] and state.blocks_to_add == [] do
      Process.send_after(self(), :render, state.refresh_every)
    end

    {:noreply,
     %{
       state
       | blocks_to_add: state.blocks_to_add ++ [block_id],
         messages: Map.put(state.messages, block_id, message),
         handlers: Map.put(state.handlers, block_id, handler)
     }}
  end

  def handle_cast({:send, block_id, message}, state) do
    {:noreply,
     %{
       state
       | messages: Map.put(state.messages, block_id, message)
     }}
  end

  def handle_cast({:put_above, message}, state) do
    {:noreply, %{state | put_above: [message | state.put_above]}}
  end

  @impl true
  def handle_info(:render, state) do
    state = render(state)
    Process.send_after(self(), :render, state.refresh_every)
    {:noreply, state}
  end

  defp get_terminal_width(:auto), do: Owl.IO.columns()
  defp get_terminal_width(number) when is_integer(number), do: number

  defp render(state) do
    terminal_width = get_terminal_width(state.terminal_width)

    {state, render_above_data} = render_above(state, terminal_width)

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
      Owl.IO.puts(data)
    end

    %{state | messages: %{}}
  end

  defp get_content(state, block_id, terminal_width) do
    case Map.fetch(state.messages, block_id) do
      {:ok, message} ->
        block_content = state.handlers[block_id].(message)

        lines =
          block_content
          |> Owl.Data.lines()
          |> Enum.flat_map(&Owl.Data.chunk_every(&1, terminal_width))

        {Owl.Data.unlines(lines), length(lines)}

      :error ->
        {state.content[block_id], state.rendered_content_height[block_id]}
    end
  end

  defp render_above(%{put_above: []} = state, _terminal_width), do: {state, []}

  defp render_above(%{put_above: put_above} = state, terminal_width) do
    put_above = put_above |> Enum.reverse() |> Owl.Data.unlines()
    screen_height = Enum.sum(Map.values(state.rendered_content_height))

    data = [
      if(screen_height == 0, do: [], else: IO.ANSI.cursor_up(screen_height)),
      Owl.Box.new(put_above,
        min_width: terminal_width,
        border_style: :none
      )
    ]

    {%{state | put_above: []}, data}
  end

  defp rerender_updated_blocks(state, rendered_above?, terminal_width) do
    blocks_to_replace = Map.keys(state.messages) -- state.blocks_to_add

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

              {[
                 %{
                   offset: next_offset,
                   content:
                     Owl.Box.new(block_content,
                       min_width: terminal_width,
                       border_style: :none,
                       min_height: max_height
                     )
                 }
               ],
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
end
