defmodule Owl.Box do
  @moduledoc """
  Allows wrapping data to boxes.
  """
  @border_styles %{
    none: %{
      top_left: "",
      top: "",
      top_right: "",
      right: "",
      left: "",
      bottom_left: "",
      bottom: "",
      bottom_right: ""
    },
    solid: %{
      top_left: "┌",
      top: "─",
      top_right: "┐",
      right: "│",
      left: "│",
      bottom_left: "└",
      bottom: "─",
      bottom_right: "┘"
    },
    double: %{
      top_left: "╔",
      top: "═",
      top_right: "╗",
      right: "║",
      left: "║",
      bottom_left: "╚",
      bottom: "═",
      bottom_right: "╝"
    }
  }
  @title_padding_left 1
  @title_padding_right 4
  @doc """
  Wraps data into a box.

  Options are self-descriptive in definition of the type `t:opt/0`, numbers mean number of symbols.

  ## Examples

      iex> "Owl" |> Owl.Box.new() |> to_string()
      \"""
      ┌───┐
      │Owl│
      └───┘
      \""" |> String.trim_trailing()


      iex> "Hello\\nworld!"
      ...> |> Owl.Box.new(
      ...>   title: "Greeting!",
      ...>   min_width: 20,
      ...>   horizontal_align: :center,
      ...>   border_style: :double
      ...> )
      ...> |> to_string()
      \"""
      ╔═Greeting!══════════╗
      ║       Hello        ║
      ║       world!       ║
      ╚════════════════════╝
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
      │  │
      │OK│
      │  │
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
      ...> |> Owl.Tag.new(:green)
      ...> |> Owl.Box.new(title: Owl.Tag.new("Red!", :red))
      ...> |> Owl.Tag.new(:cyan)
      ...> |> Owl.Data.to_ansidata()
      ...> |> to_string()
      \"""
      \e[36m┌─\e[31mRed!\e[36m\e[49m────┐\e[39m\e[49m
      \e[36m│\e[32mGreen!\e[36m\e[49m   │\e[39m\e[49m
      \e[36m└─────────┘\e[39m\e[49m\e[0m
      \""" |> String.trim_trailing()
  """
  @type opt ::
          {:padding_top, non_neg_integer()}
          | {:padding_bottom, non_neg_integer()}
          | {:padding_right, non_neg_integer()}
          | {:padding_left, non_neg_integer()}
          | {:min_height, non_neg_integer()}
          | {:min_width, non_neg_integer()}
          | {:max_width, non_neg_integer()}
          | {:horizontal_align, :left | :center | :right}
          | {:vertical_align, :top | :middle | :bottom}
          | {:border_style, :solid | :double | :none}
          | {:title, nil | Owl.Data.t()}
  @spec new(Owl.Data.t(), [opt()]) :: Owl.Data.t()
  def new(data, opts \\ []) do
    padding_top = Keyword.get(opts, :padding_top, 0)
    padding_bottom = Keyword.get(opts, :padding_bottom, 0)
    padding_left = Keyword.get(opts, :padding_left, 0)
    padding_right = Keyword.get(opts, :padding_right, 0)
    min_width = Keyword.get(opts, :min_width, 0)
    min_height = Keyword.get(opts, :min_height, 0)
    max_width = Keyword.get_lazy(opts, :max_width, &Owl.LiveScreen.width/0)
    horizontal_align = Keyword.get(opts, :horizontal_align, :left)
    vertical_align = Keyword.get(opts, :vertical_align, :top)
    border_style = Keyword.get(opts, :border_style, :solid)
    border_symbols = Map.fetch!(@border_styles, border_style)
    title = Keyword.get(opts, :title)

    max_width =
      case border_style do
        :none -> max_width
        _ -> max_width - 2
      end

    lines =
      data
      |> Owl.Data.lines()
      |> Enum.flat_map(fn line ->
        Owl.Data.chunk_every(line, max_width)
      end)

    lines_number = Enum.count(lines)
    height = max(lines_number, min_height)

    {padding_before, padding_after} =
      case vertical_align do
        :top ->
          {padding_top, padding_bottom + height - lines_number}

        :middle ->
          to_center = div(height - lines_number, 2)
          {padding_top + to_center, height - lines_number - to_center + padding_bottom}

        :bottom ->
          {padding_bottom + height - lines_number, padding_top}
      end

    lines =
      List.duplicate({[], 0}, padding_before) ++
        Enum.map(lines, fn line ->
          {line, Owl.Data.length(line)}
        end) ++ List.duplicate({[], 0}, padding_after)

    title_length = if is_nil(title), do: 0, else: Owl.Data.length(title)

    width =
      Enum.max([
        min_width,
        if(is_nil(title), do: 0, else: title_length + @title_padding_left + @title_padding_right)
        | Enum.map(lines, &elem(&1, 1))
      ])

    top_border =
      case border_style do
        :none ->
          []

        _ ->
          [
            border_symbols.top_left,
            if is_nil(title) do
              String.duplicate(border_symbols.top, width + padding_left + padding_right)
            else
              [
                String.duplicate(border_symbols.top, @title_padding_left),
                title,
                String.duplicate(
                  border_symbols.top,
                  width - title_length + padding_left + padding_right - @title_padding_left -
                    @title_padding_right
                ),
                String.duplicate(border_symbols.top, @title_padding_right)
              ]
            end,
            border_symbols.top_right,
            "\n"
          ]
      end

    bottom_border =
      case border_style do
        :none ->
          []

        _ ->
          [
            if(height > 0, do: "\n", else: []),
            border_symbols.bottom_left,
            String.duplicate(border_symbols.bottom, width + padding_left + padding_right),
            border_symbols.bottom_right
          ]
      end

    [
      top_border,
      lines
      |> Enum.map(fn {line, length} ->
        {padding_before, padding_after} =
          case horizontal_align do
            :left ->
              {padding_left, width - length + padding_right}

            :right ->
              {width - length + padding_left, padding_right}

            :center ->
              to_center = div(width - length, 2)
              {padding_left + to_center, width - length - to_center + padding_right}
          end

        [
          border_symbols.left,
          String.duplicate(" ", padding_before),
          line,
          String.duplicate(" ", padding_after),
          border_symbols.right
        ]
      end)
      |> Owl.Data.unlines(),
      bottom_border
    ]
  end
end
