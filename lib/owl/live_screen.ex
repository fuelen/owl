defmodule Owl.LiveScreen do
  use GenServer

  def start(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_block(block_name, content) do
    GenServer.cast(__MODULE__, {:add_block, block_name, content})
  end

  def replace_block(block_name, content) do
    GenServer.cast(__MODULE__, {:replace_block, block_name, content})
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  def render do
    GenServer.call(__MODULE__, :render)
  end

  @impl true
  def init(opts) do
    refresh_every = opts[:refresh_every] || 300
    Process.send_after(self(), :render, refresh_every)

    {:ok,
     %{
       refresh_every: refresh_every,
       content: %{},
       rendered_blocks: [],
       rendered_content_height: %{},
       blocks_to_add: [],
       blocks_to_replace: MapSet.new()
     }}
  end

  @impl true
  def handle_call(:render, _from, state) do
    render(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:add_block, block_name, content}, state) do
    {:noreply,
     %{
       state
       | blocks_to_add: state.blocks_to_add ++ [block_name],
         content: Map.put(state.content, block_name, content)
     }}
  end

  @impl true
  def handle_cast(:clear, state) do
    {:noreply,
     %{
       state
       | content: %{},
         rendered_blocks: [],
         rendered_content_height: %{},
         blocks_to_add: [],
         blocks_to_replace: MapSet.new()
     }}
  end

  def handle_cast({:replace_block, block_name, content}, state) do
    {:noreply,
     %{
       state
       | content: Map.put(state.content, block_name, content),
         blocks_to_replace: MapSet.put(state.blocks_to_replace, block_name)
     }}
  end

  @impl true
  def handle_info(:render, state) do
    state = render(state)

    Process.send_after(self(), :render, state.refresh_every)
    {:noreply, state}
  end

  defp render(state) do
    %{
      state
      | blocks_to_replace:
          MapSet.new(MapSet.to_list(state.blocks_to_replace) -- state.blocks_to_add)
    }
    |> rerender_updated_blocks()
    |> render_added_blocks()
  end

  defp rerender_updated_blocks(state) do
    if Enum.empty?(state.blocks_to_replace) do
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
            if force_rerender? or block_name in state.blocks_to_replace do
              block_content = state.content[block_name]
              lines = Owl.Data.lines(block_content)
              height = length(lines)
              max_height = max(height, state.rendered_content_height[block_name])

              {[
                 %{
                   offset: next_offset,
                   content:
                     Owl.Box.new(block_content,
                       min_width: 80,
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
                       Map.put(state.rendered_content_height, block_name, max_height)
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

      state = %{state | blocks_to_replace: MapSet.new()}

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
      state.blocks_to_add
      |> Enum.map_reduce(state, fn block_name, state ->
        block_content = state.content[block_name]
        lines = Owl.Data.lines(block_content)
        height = length(lines)

        {block_content,
         %{
           state
           | rendered_content_height: Map.put(state.rendered_content_height, block_name, height)
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
end
