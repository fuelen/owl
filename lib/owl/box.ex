defmodule Owl.Box do
  @moduledoc """
  Allows wrapping data to boxes.
  """

  @title_padding_left 1
  @title_padding_right 4
  @doc ~S"""
  Wraps data into a box.

  ## Options
  * `:padding` - sets the padding area for all four sides at once.  Defaults to 0.
  * `:padding_x` - sets `:padding_right` and `:padding_left` at once. Overrides value set by `:padding`. Defaults to 0.
  * `:padding_y` - sets `:padding_top` and `:padding_bottom` at once. Overrides value set by `:padding`. Defaults to 0.
  * `:padding_top` - sets the padding area for top side. Overrides value set by `:padding_y` or `:padding`.  Defaults to 0.
  * `:padding_bottom` - sets the padding area for bottom side. Overrides value set by `:padding_y` or `:padding`. Defaults to 0.
  * `:padding_right` - sets the padding area for right side. Overrides value set by `:padding_x` or `:padding`. Defaults to 0.
  * `:padding_left` - sets the padding area for left side. Overrides value set by `:padding_x` or `:padding`. Defaults to 0.
  * `:min_height` - sets the minimum height of the box, including paddings and size of the borders. Defaults to 0.
  * `:min_width` - sets the minimum width of the box, including paddings and size of the borders. Defaults to 0.
  * `:max_width` - sets the maximum width of the box, including paddings and size of the borders. Defaults to width of the terminal, if available, `:infinity` otherwise.
  * `:horizontal_align` - sets the horizontal alignment of the content inside a box. Defaults to `:right`.
  * `:vertical_align` - sets the vertical alignment of the content inside a box. Defaults to `:top`.
  * `:border_style` - sets the border style. Defaults to `:solid`.
  * `:border_tag` - sets the tag for border characters. See `t:Owl.Data.sequence/0` for a valid sequences Defaults to `[]`.
  * `:title` - sets a title that is displayed in a top border. Ignored if `:border_style` is `:none`. Defaults to `nil`.
  * `:word_wrap` - sets the word wrapping mode. Can be `:break_word` or `:normal`. Defaults to `:break_word`. Ignored if `:truncate_lines` is `true`.
  * `:truncate_lines` - specifies whether to truncate lines that are too long to fit into a box. Defaults to `false`.

  ## Examples

      iex> "Owl" |> Owl.Box.new() |> to_string()
      \"""
      ┌───┐
      │Owl│
      └───┘
      \""" |> String.trim_trailing()

      iex> "Owl" |> Owl.Box.new(padding_x: 4) |> to_string()
      \"""
      ┌───────────┐
      │    Owl    │
      └───────────┘
      \""" |> String.trim_trailing()

      iex> "Hello\nworld!"
      ...> |> Owl.Box.new(
      ...>   title: "Greeting!",
      ...>   min_width: 20,
      ...>   horizontal_align: :center,
      ...>   border_style: :double
      ...> )
      ...> |> to_string()
      \"""
      ╔═Greeting!════════╗
      ║      Hello       ║
      ║      world!      ║
      ╚══════════════════╝
      \""" |> String.trim_trailing()

      iex> "Success"
      ...> |> Owl.Box.new(
      ...>   min_width: 20,
      ...>   min_height: 3,
      ...>   border_style: :none,
      ...>   horizontal_align: :right,
      ...>   vertical_align: :bottom
      ...> )
      ...> |> to_string()
      \"""
                          
                          
                   Success
      \""" |> String.trim_trailing()

      iex> "OK"
      ...> |> Owl.Box.new(min_height: 5, vertical_align: :middle)
      ...> |> to_string()
      \"""
      ┌──┐
      │  │
      │OK│
      │  │
      └──┘
      \""" |> String.trim_trailing()

      iex> "VeryLongLine" |> Owl.Box.new(max_width: 6) |> to_string()
      \"""
      ┌────┐
      │Very│
      │Long│
      │Line│
      └────┘
      \""" |> String.trim_trailing()

      iex> "VeryLongLine" |> Owl.Box.new(max_width: 4, border_style: :none) |> to_string()
      \"""
      Very
      Long
      Line
      \""" |> String.trim_trailing()

      iex> "Green!"
      ...> |> Owl.Data.tag(:green)
      ...> |> Owl.Box.new(title: Owl.Data.tag("Red!", :red))
      ...> |> Owl.Data.tag(:cyan)
      ...> |> Owl.Data.to_chardata()
      ...> |> to_string()
      \"""
      \e[36m┌─\e[31mRed!\e[36m────┐\e[39m
      \e[36m│\e[32mGreen!\e[36m   │\e[39m
      \e[36m└─────────┘\e[39m\e[0m
      \""" |> String.trim_trailing()

      iex> "Green!"
      ...> |> Owl.Data.tag(:green)
      ...> |> Owl.Box.new(title: Owl.Data.tag("Red!", :red))
      ...> |> Owl.Data.tag(:cyan)
      ...> |> Owl.Data.to_chardata()
      ...> |> to_string()
      \"""
      \e[36m┌─\e[31mRed!\e[36m────┐\e[39m
      \e[36m│\e[32mGreen!\e[36m   │\e[39m
      \e[36m└─────────┘\e[39m\e[0m
      \""" |> String.trim_trailing()

      iex> "Hello\nworld!"
      ...> |> Owl.Box.new(
      ...>   min_width: 20,
      ...>   horizontal_align: :center,
      ...>   border_style: :double,
      ...>   border_tag: :cyan
      ...> )
      ...> |> Owl.Data.to_chardata()
      ...> |> to_string()
      \"""
      \e[36m╔\e[39m\e[36m══════════════════\e[39m\e[36m╗\e[39m
      \e[36m║\e[39m      Hello       \e[36m║\e[39m
      \e[36m║\e[39m      world!      \e[36m║\e[39m
      \e[36m╚\e[39m\e[36m══════════════════\e[39m\e[36m╝\e[39m\e[0m
      \""" |> String.trim_trailing()

      iex> "Hello\nworld!"
      ...> |> Owl.Box.new(
      ...>   title: "Greeting!",
      ...>   min_width: 20,
      ...>   horizontal_align: :center,
      ...>   border_style: :double,
      ...>   border_tag: :cyan
      ...> )
      ...> |> Owl.Data.to_chardata()
      ...> |> to_string()
      \"""
      \e[36m╔\e[39m\e[36m═\e[39mGreeting!\e[36m════════\e[39m\e[36m╗\e[39m
      \e[36m║\e[39m      Hello       \e[36m║\e[39m
      \e[36m║\e[39m      world!      \e[36m║\e[39m
      \e[36m╚\e[39m\e[36m══════════════════\e[39m\e[36m╝\e[39m\e[0m
      \""" |> String.trim_trailing()
  """
  @spec new(Owl.Data.t(),
          padding: non_neg_integer(),
          padding_x: non_neg_integer(),
          padding_y: non_neg_integer(),
          padding_top: non_neg_integer(),
          padding_bottom: non_neg_integer(),
          padding_right: non_neg_integer(),
          padding_left: non_neg_integer(),
          min_height: non_neg_integer(),
          min_width: non_neg_integer(),
          max_width: non_neg_integer() | :infinity,
          horizontal_align: :left | :center | :right,
          vertical_align: :top | :middle | :bottom,
          border_style: :solid | :solid_rounded | :double | :none,
          border_tag: Owl.Data.sequence() | [Owl.Data.sequence()],
          word_wrap: :normal | :break_word,
          truncate_lines: boolean(),
          title: nil | Owl.Data.t()
        ) :: Owl.Data.t()
  def new(data, opts \\ []) do
    padding = Keyword.get(opts, :padding, 0)
    padding_x = Keyword.get(opts, :padding_x, padding)
    padding_y = Keyword.get(opts, :padding_y, padding)
    padding_top = Keyword.get(opts, :padding_top, padding_y)
    padding_bottom = Keyword.get(opts, :padding_bottom, padding_y)
    padding_left = Keyword.get(opts, :padding_left, padding_x)
    padding_right = Keyword.get(opts, :padding_right, padding_x)
    min_width = Keyword.get(opts, :min_width, 0)
    min_height = Keyword.get(opts, :min_height, 0)
    horizontal_align = Keyword.get(opts, :horizontal_align, :left)
    vertical_align = Keyword.get(opts, :vertical_align, :top)
    title = Keyword.get(opts, :title)
    border_style = Keyword.get(opts, :border_style, :solid)
    word_wrap = Keyword.get(opts, :word_wrap, :break_word)
    truncate_lines = Keyword.get(opts, :truncate_lines, false)

    border =
      if border_style != :none do
        %{
          symbols: Owl.BorderStyle.fetch!(border_style),
          sequences: Keyword.get(opts, :border_tag, [])
        }
      else
        %{}
      end

    max_width = opts[:max_width] || Owl.IO.columns() || :infinity

    if is_integer(max_width) and max_width < 2 and border_style != :none do
      raise ArgumentError,
            "`:max_width` must be at least 2 when `:border_style` is not `:none`, got: #{max_width}"
    end

    max_width =
      if is_integer(max_width) and max_width < min_width do
        min_width
      else
        max_width
      end

    max_inner_width =
      case max_width do
        :infinity -> :infinity
        width -> width - borders_size(border_style) - padding_right - padding_left
      end

    lines =
      data
      |> Owl.Data.lines()
      |> Owl.Lines.format(max_inner_width, word_wrap, truncate_lines)

    data_height = length(lines)

    inner_height =
      max(
        data_height,
        min_height - borders_size(border_style) - padding_bottom - padding_top
      )

    {padding_before, padding_after} =
      case vertical_align do
        :top ->
          {padding_top, padding_bottom + inner_height - data_height}

        :middle ->
          to_center = div(inner_height - data_height, 2)
          {padding_top + to_center, inner_height - data_height - to_center + padding_bottom}

        :bottom ->
          {padding_bottom + inner_height - data_height, padding_top}
      end

    lines =
      List.duplicate({[], 0}, padding_before) ++
        Enum.map(lines, fn line ->
          {line, Owl.Data.length(line)}
        end) ++ List.duplicate({[], 0}, padding_after)

    min_width_required_by_title =
      if is_nil(title) do
        0
      else
        Owl.Data.length(title) + @title_padding_left + @title_padding_right +
          borders_size(border_style)
      end

    if is_integer(max_width) and min_width_required_by_title > max_width do
      raise ArgumentError, "`:title` is too big for given `:max_width`"
    end

    inner_width =
      Enum.max([
        min_width - padding_right - padding_left - borders_size(border_style),
        min_width_required_by_title - padding_right - padding_left - borders_size(border_style)
        | Enum.map(lines, fn {_line, line_length} -> line_length end)
      ])

    top_border =
      case border_style do
        :none ->
          []

        _ ->
          [
            border_tag(border, :top_left),
            if is_nil(title) do
              border_tag(border, :horizontal, inner_width + padding_left + padding_right)
            else
              [
                border_tag(border, :horizontal, @title_padding_left),
                title,
                border_tag(
                  border,
                  :horizontal,
                  inner_width - (min_width_required_by_title - borders_size(border_style)) +
                    padding_left + padding_right + @title_padding_right
                )
              ]
            end,
            border_tag(border, :top_right),
            "\n"
          ]
      end

    bottom_border =
      case border_style do
        :none ->
          []

        _ ->
          [
            if(inner_height > 0, do: "\n", else: []),
            border_tag(border, :bottom_left),
            border_tag(border, :horizontal, inner_width + padding_left + padding_right),
            border_tag(border, :bottom_right)
          ]
      end

    [
      top_border,
      lines
      |> Enum.map(fn {line, length} ->
        {padding_before, padding_after} =
          case horizontal_align do
            :left ->
              {padding_left, inner_width - length + padding_right}

            :right ->
              {inner_width - length + padding_left, padding_right}

            :center ->
              to_center = div(inner_width - length, 2)
              {padding_left + to_center, inner_width - length - to_center + padding_right}
          end

        [
          if(border_style == :none, do: [], else: border_tag(border, :vertical)),
          String.duplicate(" ", padding_before),
          line,
          String.duplicate(" ", padding_after),
          if(border_style == :none, do: [], else: border_tag(border, :vertical))
        ]
      end)
      |> Owl.Data.unlines(),
      bottom_border
    ]
  end

  defp borders_size(:none = _border_style), do: 0
  defp borders_size(_border_style), do: 2

  defp border_tag(border, symbol, repeat \\ 1)

  defp border_tag(%{symbols: symbols, sequences: []}, symbol, repeat) do
    symbols
    |> Map.fetch!(symbol)
    |> String.duplicate(repeat)
  end

  defp border_tag(%{symbols: symbols, sequences: sequences}, symbol, repeat) do
    symbols
    |> Map.fetch!(symbol)
    |> String.duplicate(repeat)
    |> Owl.Data.tag(sequences)
  end
end
