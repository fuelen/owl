defmodule Owl.LiveScreen do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_block(block_name, params) do
    GenServer.cast(__MODULE__, {:add_block, block_name, params})
  end

  def send(block_name, message) do
    GenServer.cast(__MODULE__, {:send, block_name, message})
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  @impl true
  def init(opts) do
    refresh_every = opts[:refresh_every] || 100

    {:ok,
     %{
       refresh_every: refresh_every,
       content: %{},
       messages: %{},
       handlers: %{},
       rendered_blocks: [],
       rendered_content_height: %{},
       blocks_to_add: []
     }}
  end

  @impl true
  def terminate(_, state) do
    render(state)
  end

  @impl true
  def handle_cast({:add_block, block_name, params}, state) do
    message = params[:message]
    handler = params[:handler] || (&Function.identity/1)

    # initiate rendering when adding first block
    if state.rendered_blocks == [] and state.blocks_to_add == [] do
      Process.send_after(self(), :render, state.refresh_every)
    end

    {:noreply,
     %{
       state
       | blocks_to_add: state.blocks_to_add ++ [block_name],
         messages: Map.put(state.messages, block_name, message),
         handlers: Map.put(state.handlers, block_name, handler)
     }}
  end

  def handle_cast({:send, block_name, message}, state) do
    {:noreply,
     %{
       state
       | messages: Map.put(state.messages, block_name, message)
     }}
  end

  @impl true
  def handle_info(:render, state) do
    state = render(state)
    Process.send_after(self(), :render, state.refresh_every)
    {:noreply, state}
  end

  def handle_info({:send, block_name, message}, state) do
    {:noreply, %{state | messages: Map.put(state.messages, block_name, message)}}
  end

  defp render(state) do
    state
    |> rerender_updated_blocks()
    |> render_added_blocks()
    |> Map.put(:messages, %{})
  end

  defp get_content(state, block_name) do
    case Map.fetch(state.messages, block_name) do
      {:ok, message} -> state.handlers[block_name].(message)
      :error -> state.content[block_name]
    end
  end

  defp rerender_updated_blocks(state) do
    blocks_to_replace = Map.keys(state.messages) -- state.blocks_to_add

    if Enum.empty?(blocks_to_replace) do
      state
    else
      {content_blocks, %{total_height: total_height, state: state, next_offset: return_to_end}} =
        state.rendered_blocks
        |> Enum.flat_map_reduce(
          %{total_height: 0, next_offset: 0, force_rerender?: false, state: state},
          fn block_name,
             %{
               total_height: total_height,
               next_offset: next_offset,
               state: state,
               force_rerender?: force_rerender?
             } ->
            if force_rerender? or block_name in blocks_to_replace do
              block_content = get_content(state, block_name)

              lines = Owl.Data.lines(block_content)
              height = length(lines)
              max_height = max(height, state.rendered_content_height[block_name])

              {[
                 %{
                   offset: next_offset,
                   content:
                     Owl.Box.new(block_content,
                       min_width: width(),
                       border_style: :none,
                       min_height: max_height
                     )
                 }
               ],
               %{
                 total_height: total_height + state.rendered_content_height[block_name],
                 next_offset: 0,
                 force_rerender?:
                   force_rerender? || height > state.rendered_content_height[block_name],
                 state: %{
                   state
                   | rendered_content_height:
                       Map.put(state.rendered_content_height, block_name, max_height),
                     content: Map.put(state.content, block_name, block_content)
                 }
               }}
            else
              height = state.rendered_content_height[block_name]

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

      # TODO: optimize Owl.IO.puts, so it doesn't invoke lines+unlines before output, as this operation has been already done
      Owl.IO.puts([
        IO.ANSI.cursor_up(total_height),
        content_blocks
        |> Enum.map(fn
          %{offset: 0, content: content} -> content
          %{offset: offset, content: content} -> [IO.ANSI.cursor_down(offset), content]
        end)
        |> Owl.Data.unlines(),
        if(return_to_end == 0, do: [], else: IO.ANSI.cursor_down(return_to_end))
      ])

      state
    end
  end

  defp render_added_blocks(%{blocks_to_add: []} = state), do: state

  defp render_added_blocks(state) do
    {content_blocks, state} =
      Enum.map_reduce(state.blocks_to_add, state, fn block_name, state ->
        block_content = get_content(state, block_name)
        lines = Owl.Data.lines(block_content)
        height = length(lines)

        {block_content,
         %{
           state
           | rendered_content_height: Map.put(state.rendered_content_height, block_name, height),
             content: Map.put(state.content, block_name, block_content)
         }}
      end)

    state = %{
      state
      | blocks_to_add: [],
        rendered_blocks: state.rendered_blocks ++ state.blocks_to_add
    }

    # TODO: optimize Owl.IO.puts, so it doesn't invoke lines+unlines before output, as this operation has been already done
    content_blocks
    |> Owl.Data.unlines()
    |> Owl.IO.puts()

    state
  end

  def width do
    case :io.columns() do
      {:ok, width} ->
        # -1 fixes an issue in iex when for some reason sometimes 1 space is moved to the next line
        width - 1

      _ ->
        80
    end
  end
end
