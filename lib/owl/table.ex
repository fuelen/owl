defmodule Owl.Table do
  @moduledoc """
  Allows drawing awesome tables.
  """

  @doc """
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
  * `:sort_columns` - sets a sorter (second argument for `Enum.sort/2`) for columns. No sorter by default.
  * `:max_column_widths` - sets max width for columns. Accepts a function that returns an inner width (content + padding) for each column. Defaults to `fn _ -> :infinity end`.
  * `:show_empty_rows` - specifies whether to show empty rows. Defaults to `true`.
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
      ...> |> Owl.Data.to_ansidata()
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
  @spec new(rows :: [row :: %{column => value}],
          border_style: :solid | :solid_rounded | :none | :double,
          divide_body_rows: boolean(),
          truncate_lines: boolean(),
          filter_columns: (column -> as_boolean(term)),
          show_empty_rows: boolean(),
          padding_x: non_neg_integer(),
          max_column_widths: (column -> pos_integer() | :infinity),
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
  def new(rows, opts \\ []) do
    border_style = Keyword.get(opts, :border_style, :solid)
    border_symbols = if border_style != :none, do: Owl.BorderStyle.fetch!(border_style)

    divide_body_rows = Keyword.get(opts, :divide_body_rows, false)
    show_empty_rows = Keyword.get(opts, :show_empty_rows, true)
    truncate_lines = Keyword.get(opts, :truncate_lines, false)

    columns = columns(rows)

    columns =
      case Keyword.get(opts, :filter_columns) do
        nil -> columns
        filter_callback -> Enum.filter(columns, filter_callback)
      end

    columns =
      case Keyword.get(opts, :sort_columns) do
        nil -> columns
        sorter -> Enum.sort(columns, sorter)
      end

    padding_x = opts[:padding_x] || 0

    {render_body_cell, render_header_cell} =
      case Keyword.get(opts, :render_cell) || (&Function.identity/1) do
        render when is_function(render, 1) ->
          {render, render}

        opts when is_list(opts) ->
          {opts[:body] || (&Function.identity/1), opts[:header] || (&Function.identity/1)}
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

    rows =
      normalize_rows(
        rows,
        columns,
        render_body_cell,
        render_header_cell,
        max_content_widths,
        show_empty_rows,
        truncate_lines
      )

    column_widths =
      rows
      |> Enum.map(fn row ->
        Map.new(row, fn cell ->
          {cell.column, cell.width}
        end)
      end)
      |> Enum.reduce(&Map.merge(&1, &2, fn _key, v1, v2 -> max(v1, v2) end))

    render(rows, columns, column_widths, divide_body_rows, border_symbols, padding_x)
  end

  defp render(rows, _columns, column_widths, _divide_body_rows, nil = border_symbols, padding_x) do
    padding_x_symbols = List.duplicate(" ", padding_x)

    Enum.map_intersperse(
      rows,
      "\n",
      fn row -> render_row(row, column_widths, border_symbols, padding_x_symbols) end
    )
  end

  defp render(rows, columns, column_widths, divide_body_rows, border_symbols, padding_x) do
    padding_x_symbols = List.duplicate(" ", padding_x)

    horizontal_border =
      columns
      |> Enum.map(fn column ->
        List.duplicate(border_symbols.horizontal, column_widths[column] + padding_x * 2)
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

    [header | body] = rows

    [
      top_border,
      render_row(header, column_widths, border_symbols, padding_x_symbols),
      internal_horizontal_border,
      Enum.map_intersperse(
        body,
        if divide_body_rows do
          internal_horizontal_border
        else
          "\n"
        end,
        fn row -> render_row(row, column_widths, border_symbols, padding_x_symbols) end
      ),
      bottom_border
    ]
  end

  @empty_line %{length: 0, value: []}
  defp render_row(row, column_widths, border_symbols, padding_x_symbols) do
    row_height = row |> Enum.reduce(0, &max(&1.height, &2))

    row
    |> Enum.flat_map(fn cell ->
      lines = cell.lines ++ List.duplicate(@empty_line, row_height - cell.height)

      Enum.map(lines, fn line ->
        [line.value, List.duplicate(" ", column_widths[cell.column] - line.length)]
      end)
    end)
    |> Enum.chunk_every(row_height)
    |> Enum.zip_with(
      if is_nil(border_symbols) do
        fn elements ->
          Enum.intersperse(elements, [padding_x_symbols, padding_x_symbols])
        end
      else
        fn elements ->
          Enum.intersperse(elements, [
            padding_x_symbols,
            border_symbols.vertical,
            padding_x_symbols
          ])
        end
      end
    )
    |> Enum.map_intersperse(
      "\n",
      if is_nil(border_symbols) do
        fn row ->
          [padding_x_symbols, row, padding_x_symbols]
        end
      else
        fn row ->
          [
            border_symbols.vertical,
            padding_x_symbols,
            row,
            padding_x_symbols,
            border_symbols.vertical
          ]
        end
      end
    )
  end

  defp columns(rows) do
    rows
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
  end

  defp to_lines(content, max_content_width, show_empty_rows, truncate_lines) do
    lines = Owl.Data.lines(content)

    lines =
      case max_content_width do
        :infinity ->
          lines

        max_width ->
          if truncate_lines do
            Enum.map(lines, fn line -> Owl.Data.truncate(line, max_width) end)
          else
            Enum.flat_map(lines, fn line -> Owl.Data.chunk_every(line, max_width) end)
          end
      end

    lines =
      Enum.map(lines, fn line ->
        %{value: line, length: Owl.Data.length(line)}
      end)

    if show_empty_rows and lines == [] do
      [%{value: [], length: 0}]
    else
      lines
    end
  end

  defp normalize_rows(
         rows,
         columns,
         render_body_cell,
         render_header_cell,
         max_content_widths,
         show_empty_rows,
         truncate_lines
       ) do
    [
      Enum.map(columns, fn column ->
        lines =
          column
          |> render_header_cell.()
          |> to_lines(max_content_widths[column], show_empty_rows, truncate_lines)

        %{
          column: column,
          lines: lines,
          height: length(lines),
          width: lines |> Enum.reduce(0, &max(&1.length, &2))
        }
      end)
      | Enum.flat_map(rows, fn row ->
          {row, empty_row?} =
            Enum.map_reduce(columns, true, fn column, empty_row? ->
              value =
                case Map.fetch(row, column) do
                  :error ->
                    []

                  {:ok, value} ->
                    case render_body_cell do
                      render when is_function(render, 1) -> render.(value)
                      render when is_function(render, 2) -> render.(column, value)
                    end
                end

              lines = to_lines(value, max_content_widths[column], show_empty_rows, truncate_lines)

              width = lines |> Enum.reduce(0, &max(&1.length, &2))

              {%{
                 column: column,
                 lines: lines,
                 height: length(lines),
                 width: width
               }, empty_row? and width == 0}
            end)

          if not show_empty_rows and empty_row? do
            []
          else
            [row]
          end
        end)
    ]
  end
end
