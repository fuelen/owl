owl =
  """
     ,_,
    {o,o}
    /)  )
  ---"-"--
  """
  |> String.trim_trailing()

owl_height = 4
owl_width = 8

width = 60
height = 20
colors = [:red, :yellow, :cyan, :blue, :green]

Owl.LiveScreen.add_block(:demo,
  render: fn
    nil ->
      ""

    state ->
      owl
      |> Owl.Data.tag(state.owl_color)
      |> Owl.Box.new(
        min_width: width - state.padding_left,
        min_height: height - state.padding_top,
        padding_top: state.padding_top,
        padding_left: state.padding_left
      )
      |> Owl.Data.tag(:magenta)
  end
)

Stream.iterate(
  %{
    padding_top: 10,
    padding_left: 30,
    vertical_shift: 1,
    horizontal_shift: -1,
    owl_color: Enum.random(colors)
  },
  fn state ->
    horizontal_shift =
      cond do
        state.padding_left == 0 or width - state.padding_left - owl_width == 0 ->
          state.horizontal_shift * -1

        state.padding_left > 0 ->
          state.horizontal_shift
      end

    vertical_shift =
      cond do
        state.padding_top == 0 or height - state.padding_top - owl_height == 0 ->
          state.vertical_shift * -1

        state.padding_top > 0 ->
          state.vertical_shift
      end

    owl_color =
      if vertical_shift != state.vertical_shift or horizontal_shift != state.horizontal_shift do
        Enum.random(colors)
      else
        state.owl_color
      end

    padding_left = state.padding_left + horizontal_shift
    padding_top = state.padding_top + vertical_shift

    Owl.LiveScreen.update(:demo, %{
      padding_left: padding_left,
      padding_top: padding_top,
      owl_color: owl_color
    })

    Process.sleep(50)

    %{
      padding_left: padding_left,
      padding_top: padding_top,
      vertical_shift: vertical_shift,
      horizontal_shift: horizontal_shift,
      owl_color: owl_color
    }
  end
)
|> Stream.run()
