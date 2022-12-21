defmodule Owl.TableTest do
  use ExUnit.Case, async: true
  doctest Owl.Table

  describe inspect(&Owl.Table.new/2) do
    test "no options" do
      assert_tables_equal(
        [
          %{"id" => "1", "name" => "Yaroslav"},
          %{"id" => "2", "name" => "Volodymyr"}
        ],
        [],
        """
        ┌──┬─────────┐
        │id│name     │
        ├──┼─────────┤
        │1 │Yaroslav │
        │2 │Volodymyr│
        └──┴─────────┘
        """
      )
    end

    test "max_column_widths: pos_integer" do
      assert_tables_equal(
        [
          %{"a" => "123456"},
          %{"b" => "qwerty"}
        ],
        [
          max_column_widths: fn
            "a" -> 5
            "b" -> 3
          end
        ],
        """
        ┌─────┬───┐
        │a    │b  │
        ├─────┼───┤
        │12345│   │
        │6    │   │
        │     │qwe│
        │     │rty│
        └─────┴───┘
        """
      )
    end

    test "max_column_widths: less than or equal to :padding_x" do
      assert_raise(RuntimeError, fn ->
        Owl.Table.new([%{"a" => "qwerty"}], padding_x: 2, max_column_widths: fn _ -> 2 end)
      end)

      assert_raise(RuntimeError, fn ->
        Owl.Table.new([%{"a" => "qwerty"}], padding_x: 2, max_column_widths: fn _ -> 1 end)
      end)
    end

    test "border_style: :none" do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"}
        ],
        [border_style: :none],
        """
        ab
        1 
         2
        """
      )
    end

    test "border_style: :none + padding_x: n" do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"}
        ],
        [border_style: :none, padding_x: 2],
        """
          a    b  
          1       
               2  
        """
      )
    end

    test "border_style: :double" do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"}
        ],
        [border_style: :double],
        """
        ╔═╦═╗
        ║a║b║
        ╠═╬═╣
        ║1║ ║
        ║ ║2║
        ╚═╩═╝
        """
      )
    end

    test "border_style: :solid_rounded " do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"}
        ],
        [border_style: :solid_rounded],
        """
        ╭─┬─╮
        │a│b│
        ├─┼─┤
        │1│ │
        │ │2│
        ╰─┴─╯
        """
      )
    end

    test ":sort_columns" do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"},
          %{"c" => "3"}
        ],
        [sort_columns: :desc],
        """
        ┌─┬─┬─┐
        │c│b│a│
        ├─┼─┼─┤
        │ │ │1│
        │ │2│ │
        │3│ │ │
        └─┴─┴─┘
        """
      )
    end

    test ":filter_columns, show_empty_rows: true (default)" do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"},
          %{"c" => "3"}
        ],
        [filter_columns: &(&1 in ["a", "c"])],
        """
        ┌─┬─┐
        │a│c│
        ├─┼─┤
        │1│ │
        │ │ │
        │ │3│
        └─┴─┘
        """
      )
    end

    test ":filter_columns, show_empty_rows: false" do
      assert_tables_equal(
        [
          %{"a" => "1"},
          %{"b" => "2"},
          %{"c" => "3"}
        ],
        [filter_columns: &(&1 in ["a", "c"]), show_empty_rows: false],
        """
        ┌─┬─┐
        │a│c│
        ├─┼─┤
        │1│ │
        │ │3│
        └─┴─┘
        """
      )
    end

    test ":render_cell with common handler" do
      assert_tables_equal(
        [
          %{a: :q, b: :a},
          %{a: :z, b: :d}
        ],
        [render_cell: &inspect/1],
        """
        ┌──┬──┐
        │:a│:b│
        ├──┼──┤
        │:q│:a│
        │:z│:d│
        └──┴──┘
        """
      )
    end

    test ":render_cell with different header and body handlers" do
      assert_tables_equal(
        [
          %{a: :qwertyuiop, b: :asdfghjkl},
          %{a: :zxcvbnm, b: :dcb}
        ],
        [
          render_cell: [
            header: &(&1 |> inspect() |> Owl.Data.tag(:red)),
            body: &(&1 |> inspect() |> Owl.Data.truncate(8) |> Owl.Data.tag(:yellow))
          ]
        ],
        """
        ┌────────┬────────┐
        │\e[31m:a\e[39m      │\e[31m:b\e[39m      │
        ├────────┼────────┤
        │\e[33m:qwerty…\e[39m│\e[33m:asdfgh…\e[39m│
        │\e[33m:zxcvbnm\e[39m│\e[33m:dcb\e[39m    │
        └────────┴────────┘\e[0m
        """
      )
    end

    test "multiline cells and divide_body_rows" do
      assert_tables_equal(
        [
          %{
            "a\nb" => "n\nm",
            "c\nd" => "k\nl"
          },
          %{
            "a\nb" => "r\nq\ns",
            "c\nd" => "o\np"
          }
        ],
        [divide_body_rows: true],
        """
        ┌─┬─┐
        │a│c│
        │b│d│
        ├─┼─┤
        │n│k│
        │m│l│
        ├─┼─┤
        │r│o│
        │q│p│
        │s│ │
        └─┴─┘
        """
      )
    end
  end

  defp assert_tables_equal(rows, opts, expected_result) do
    table = Owl.Table.new(rows, opts)
    expected_result = String.trim_trailing(expected_result, "\n")

    assert table |> Owl.Data.to_ansidata() |> to_string() == expected_result,
           to_string(
             Owl.Data.to_ansidata([
               "Tables do not match\n",
               Owl.Data.tag("result:", :cyan),
               "\n",
               table,
               "\n",
               Owl.Data.tag("expected:", :cyan),
               "\n",
               expected_result
             ])
           )
  end
end
