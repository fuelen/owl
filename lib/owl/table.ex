defmodule Owl.Table do
  @moduledoc """
  Allows drawing awesome tables.
  """

  @doc ~S"""
  Draws a table.

  Accepts a list of maps, where each map represents a row.
  The keys and values of maps should have the type `t:Owl.Data.t/0`, otherwise use `:render_cell` option to make values printable.

  ## Options

  * `:border_style` - sets the border style. Defaults to `:solid`.
  * `:divide_body_rows` - specifies whether to show divider between rows in body. It is better to use it if cells have multiline values. Ignored, if `:border_style` is set to `:none`. Defaults to `false`.
  * `:filter_columns` - sets a function which filters column (second argument for `Enum.filter/2`). No filter function by default.
  * `:padding_x`- sets horizontal padding. Defaults to `0`.
  * `:render_cell` - sets how to render header and body cells. Accepts either a function or a keyword list. Defaults to `&Function.identity/1`.
  Options in case of a keyword list:
    * `:header` - sets a function to render header cell. Defaults to `&Function.identity/1`.
    * `:body` - sets a function to render body cell. Defaults to `&Function.identity/1`.
  * `:sort_columns` - sets a sorter (second argument for `Enum.sort/2`) for columns. Defaults to `:asc`.
  * `:max_column_widths` - sets max width for columns in symbols. Accepts a function that returns an inner width (content + padding) for each column. Defaults to `fn _ -> :infinity end`.
  * `:max_width` - sets a maximum width of of the table in symbols including borders. Defaults to width of the terminal or `:infinity`, if a terminal is not available.
  * `:word_wrap` - sets the word wrapping mode. Can be `:break_word` or `:normal`. Defaults to `:break_word`. Ignored if `:truncate_lines` is `true`.
  * `:truncate_lines` - specifies whether to truncate lines when they reach width specified by `:max_content_width`. Defaults to `false`.

  ## Examples

      # render as is without options
      iex> [
      ...>   %{"id" => "1", "name" => "Yaroslav"},
      ...>   %{"id" => "2", "name" => "Volodymyr"}
      ...> ] |> Owl.Table.new() |> to_string()
      \"""
      ┌──┬─────────┐
      │id│name     │
      ├──┼─────────┤
      │1 │Yaroslav │
      │2 │Volodymyr│
      └──┴─────────┘
      \""" |> String.trim_trailing()

      # ...and more complex example with a bunch of options
      iex> [
      ...>   %{a: :qwertyuiop, b: :asdfghjkl},
      ...>   %{a: :zxcvbnm, b: :dcb}
      ...> ]
      ...> |> Owl.Table.new(
      ...>   render_cell: [
      ...>     header: &(&1 |> inspect() |> Owl.Data.tag(:red)),
      ...>     body: &(&1 |> inspect() |> Owl.Data.truncate(8) |> Owl.Data.tag(:yellow))
      ...>   ],
      ...>   divide_body_rows: true,
      ...>   border_style: :solid_rounded,
      ...>   padding_x: 1,
      ...>   sort_columns: :desc
      ...> )
      ...> |> Owl.Data.to_chardata()
      ...> |> to_string()
      \"""
      ╭──────────┬──────────╮
      │ \e[31m:b\e[39m       │ \e[31m:a\e[39m       │
      ├──────────┼──────────┤
      │ \e[33m:asdfgh…\e[39m │ \e[33m:qwerty…\e[39m │
      ├──────────┼──────────┤
      │ \e[33m:dcb\e[39m     │ \e[33m:zxcvbnm\e[39m │
      ╰──────────┴──────────╯\e[0m
      \""" |> String.trim_trailing()
  """
  @spec new(rows :: nonempty_list(row :: %{column => value}),
          border_style: :solid | :solid_rounded | :none | :double,
          divide_body_rows: boolean(),
          word_wrap: :break_word | :normal,
          truncate_lines: boolean(),
          filter_columns: (column -> as_boolean(term)),
          padding_x: non_neg_integer(),
          max_column_widths: (column -> pos_integer() | :infinity),
          max_width: pos_integer() | :infinity,
          render_cell:
            [
              header: (column -> Owl.Data.t()),
              body: (value -> Owl.Data.t()) | (column, value -> Owl.Data.t())
            ]
            | (value | column -> Owl.Data.t()),
          sort_columns:
            (column, column -> boolean())
            | :asc
            | :desc
            | module()
            | {:asc | :desc, module()}
        ) :: Owl.Data.t()
        when column: any(), value: any()
  def new([_ | _] = rows, opts \\ []) do
    border_style = Keyword.get(opts, :border_style, :solid)
    border_symbols = if border_style != :none, do: Owl.BorderStyle.fetch!(border_style)

    divide_body_rows = Keyword.get(opts, :divide_body_rows, false)
    truncate_lines = Keyword.get(opts, :truncate_lines, false)
    word_wrap = Keyword.get(opts, :word_wrap, :break_word)

    columns = columns(rows)

    columns =
      case Keyword.get(opts, :filter_columns) do
        nil -> columns
        filter_callback -> Enum.filter(columns, filter_callback)
      end

    columns = Enum.sort(columns, Keyword.get(opts, :sort_columns, :asc))

    padding_x = opts[:padding_x] || 0
    max_width = opts[:max_width] || Owl.IO.columns() || :infinity

    if is_integer(max_width) and max_width < 2 do
      raise ":max_width is too small, got: #{max_width}"
    end

    render_functions =
      case Keyword.get(opts, :render_cell) || (&Function.identity/1) do
        render when is_function(render, 1) ->
          {render, render}

        opts when is_list(opts) ->
          {opts[:header] || (&Function.identity/1), opts[:body] || (&Function.identity/1)}
      end

    max_content_widths =
      case Keyword.get(opts, :max_column_widths) do
        nil ->
          Map.new(columns, &{&1, :infinity})

        get_max_column_width ->
          Map.new(columns, fn column ->
            max_content_width =
              case get_max_column_width.(column) do
                :infinity ->
                  :infinity

                width when is_integer(width) and width > 0 ->
                  if width <= padding_x * 2 do
                    raise "max column width must be bigger than `:padding_x` * 2"
                  else
                    width - padding_x
                  end
              end

            {column, max_content_width}
          end)
      end

    border_size = if is_nil(border_symbols), do: 0, else: 1

    {rows, columns_data} =
      rows
      |> apply_render_function_to_cells(columns, render_functions)
      |> apply_width_limits(
        columns,
        max_content_widths,
        word_wrap,
        truncate_lines,
        max_width,
        padding_x,
        border_size
      )

    render_table(rows, divide_body_rows, border_symbols, columns_data)
  end

  defp render_table(rows, _divide_body_rows, nil = border_symbols, columns_data) do
    Enum.map_intersperse(rows, "\n", fn row -> render_row(row, border_symbols, columns_data) end)
  end

  defp render_table([header | body], divide_body_rows, border_symbols, columns_data) do
    horizontal_border =
      Enum.map(header, fn %{column_width: column_width, column: column} ->
        column_data = columns_data[column]

        List.duplicate(
          border_symbols.horizontal,
          column_width + column_data.padding_left + column_data.padding_right
        )
      end)

    top_border = [
      border_symbols.top_left,
      Enum.intersperse(horizontal_border, border_symbols.top_cross),
      border_symbols.top_right,
      "\n"
    ]

    bottom_border = [
      "\n",
      border_symbols.bottom_left,
      Enum.intersperse(horizontal_border, border_symbols.bottom_cross),
      border_symbols.bottom_right
    ]

    internal_horizontal_border = [
      "\n",
      border_symbols.left_cross,
      Enum.intersperse(horizontal_border, border_symbols.cross),
      border_symbols.right_cross,
      "\n"
    ]

    body_rows_divider =
      if divide_body_rows do
        internal_horizontal_border
      else
        "\n"
      end

    [
      top_border,
      render_row(header, border_symbols, columns_data),
      internal_horizontal_border,
      Enum.map_intersperse(body, body_rows_divider, fn row ->
        render_row(row, border_symbols, columns_data)
      end),
      bottom_border
    ]
  end

  @empty_line %{length: 0, value: []}
  defp render_row(row, border_symbols, columns_data) do
    row_height = row |> Enum.reduce(0, &max(&1.height, &2))

    row
    |> Enum.flat_map(fn cell ->
      lines = cell.lines ++ List.duplicate(@empty_line, row_height - cell.height)
      column_data = columns_data[cell.column]

      Enum.map(lines, fn line ->
        [
          column_data.padding_left_symbols,
          line.value,
          List.duplicate(" ", column_data.width - line.length),
          column_data.padding_right_symbols
        ]
      end)
    end)
    |> Enum.chunk_every(row_height)
    |> Enum.zip_with(
      if is_nil(border_symbols) do
        &Function.identity/1
      else
        fn elements -> Enum.intersperse(elements, border_symbols.vertical) end
      end
    )
    |> Enum.map_intersperse(
      "\n",
      if is_nil(border_symbols) do
        &Function.identity/1
      else
        fn row -> [border_symbols.vertical, row, border_symbols.vertical] end
      end
    )
  end

  defp columns(rows) do
    rows
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
  end

  defp to_lines(content, max_content_width, word_wrap, truncate_lines) do
    lines =
      content
      |> Owl.Data.lines()
      |> Owl.Lines.format(max_content_width, word_wrap, truncate_lines)
      |> Enum.map(fn line ->
        %{value: line, length: Owl.Data.length(line)}
      end)

    if lines == [] do
      [%{value: [], length: 0}]
    else
      lines
    end
  end

  defp transpose(matrix) do
    Enum.zip_with(matrix, &Function.identity/1)
  end

  defp apply_render_function_to_cells(rows, columns, {render_header_cell, render_body_cell}) do
    [
      Enum.map(columns, fn column ->
        render_header_cell.(column)
      end)
      | Enum.map(rows, fn row ->
          Enum.map(columns, fn column ->
            case Map.fetch(row, column) do
              :error ->
                []

              {:ok, value} ->
                case render_body_cell do
                  render when is_function(render, 1) -> render.(value)
                  render when is_function(render, 2) -> render.(column, value)
                end
            end
          end)
        end)
    ]
  end

  defp apply_width_limits(
         rows,
         columns,
         max_content_widths,
         word_wrap,
         truncate_lines,
         max_width,
         padding_x,
         border_size
       ) do
    %{data: data, columns_data: columns_data} =
      [columns | rows]
      |> Enum.zip_with(fn [column | column_values] -> {column, column_values} end)
      |> Enum.reduce_while(
        %{
          data: [],
          columns_data: %{},
          width_left:
            case max_width do
              :infinity ->
                :infinity

              max_width ->
                start_table_border_size = border_size
                max_width - start_table_border_size
            end
        },
        fn {column, column_values},
           %{
             data: data,
             columns_data: columns_data,
             width_left: width_left
           } ->
          max_content_width = Map.fetch!(max_content_widths, column)

          width_left =
            case width_left do
              :infinity -> :infinity
              width_left -> width_left - border_size
            end

          {width_left, padding_left, padding_right} =
            case width_left do
              :infinity ->
                {:infinity, padding_x, padding_x}

              width_left ->
                padding_left = min(width_left, padding_x)
                width_left = width_left - padding_left
                padding_right = min(width_left, padding_x)
                width_left = width_left - padding_right
                {width_left, padding_left, padding_right}
            end

          max_content_width =
            case width_left do
              :infinity -> max_content_width
              width_left -> min(width_left, max_content_width)
            end

          {cells, column_width} =
            column_values
            |> Enum.map_reduce(0, fn value, max_column_width_so_far ->
              lines = to_lines(value, max_content_width, word_wrap, truncate_lines)
              width = lines |> Enum.reduce(0, &max(&1.length, &2))

              {
                %{
                  lines: lines,
                  height: length(lines),
                  column: column
                },
                max(width, max_column_width_so_far)
              }
            end)

          cells = Enum.map(cells, &Map.put(&1, :column_width, column_width))

          width_left =
            case width_left do
              :infinity -> :infinity
              width_left -> width_left - column_width
            end

          column_data = %{
            width: column_width,
            padding_left: padding_left,
            padding_left_symbols: List.duplicate(" ", padding_left),
            padding_right: padding_right,
            padding_right_symbols: List.duplicate(" ", padding_right)
          }

          {
            if(width_left == 0, do: :halt, else: :cont),
            %{
              width_left: width_left,
              data: [cells | data],
              columns_data: Map.put(columns_data, column, column_data)
            }
          }
        end
      )

    {data
     |> Enum.reverse()
     |> transpose(), columns_data}
  end
end
