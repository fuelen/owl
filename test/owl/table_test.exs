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

    test "max_column_widths: pos_integer | :infinity, truncate_lines: true" do
      assert_tables_equal(
        [
          %{"a" => "123456"},
          %{"b" => "qwerty"}
        ],
        [
          max_column_widths: fn
            "a" -> :infinity
            "b" -> 3
          end,
          truncate_lines: true
        ],
        """
        ┌──────┬───┐
        │a     │b  │
        ├──────┼───┤
        │123456│   │
        │      │qw…│
        └──────┴───┘
        """
      )
    end

    test "max_column_widths: pos_integer, truncate_lines: false (default)" do
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

    test ":filter_columns" do
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

      assert_tables_equal(
        [
          %{a: :qwertyuiop, b: :asdfghjkl},
          %{a: :zxcvbnm, b: :dcb}
        ],
        [
          render_cell: [
            header: &(&1 |> inspect()),
            body: fn
              :a, value -> inspect(value)
              :b, value -> value |> to_string() |> String.upcase()
            end
          ]
        ],
        """
        ┌───────────┬─────────┐
        │:a         │:b       │
        ├───────────┼─────────┤
        │:qwertyuiop│ASDFGHJKL│
        │:zxcvbnm   │DCB      │
        └───────────┴─────────┘
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

      assert_tables_equal(
        [
          %{
            "a\nb" => "n\n\nm",
            "c\nd" => "k\n\nl"
          },
          %{
            "a\nb" => "r\n\ns",
            "c\nd" => "o"
          }
        ],
        [divide_body_rows: true],
        """
        ┌─┬─┐
        │a│c│
        │b│d│
        ├─┼─┤
        │n│k│
        │ │ │
        │m│l│
        ├─┼─┤
        │r│o│
        │ │ │
        │s│ │
        └─┴─┘
        """
      )
    end

    test "max_width: :infinity" do
      assert_tables_equal(
        [
          %{
            "a" =>
              "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
          }
        ],
        [max_width: :infinity],
        """
        ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
        │a                                                                                               │
        ├────────────────────────────────────────────────────────────────────────────────────────────────┤
        │bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb│
        └────────────────────────────────────────────────────────────────────────────────────────────────┘
        """
      )
    end

    test "max_width < 2" do
      assert_raise(RuntimeError, fn ->
        Owl.Table.new([%{"a" => "qwerty"}], max_width: 1)
      end)

      assert_raise(RuntimeError, fn ->
        Owl.Table.new([%{"a" => "qwerty"}], max_width: 0)
      end)
    end

    test "max_width >= 2" do
      %{
        2 => """
        ┌┐
        ││
        ├┤
        ││
        ││
        └┘
        """,
        3 => """
        ┌─┐
        │ │
        ├─┤
        │ │
        │ │
        └─┘
        """,
        4 => """
        ┌──┐
        │  │
        ├──┤
        │  │
        │  │
        └──┘
        """,
        5 => """
        ┌───┐
        │ … │
        ├───┤
        │ … │
        │ … │
        └───┘
        """,
        6 => """
        ┌────┐
        │ h1 │
        ├────┤
        │ r… │
        │ r… │
        └────┘
        """,
        7 => """
        ┌─────┐
        │ h1  │
        ├─────┤
        │ r11 │
        │ r21 │
        └─────┘
        """,
        8 => """
        ┌─────┬┐
        │ h1  ││
        ├─────┼┤
        │ r11 ││
        │ r21 ││
        └─────┴┘
        """,
        9 => """
        ┌─────┬─┐
        │ h1  │ │
        ├─────┼─┤
        │ r11 │ │
        │ r21 │ │
        └─────┴─┘
        """,
        10 => """
        ┌─────┬──┐
        │ h1  │  │
        ├─────┼──┤
        │ r11 │  │
        │ r21 │  │
        └─────┴──┘
        """,
        11 => """
        ┌─────┬───┐
        │ h1  │ … │
        ├─────┼───┤
        │ r11 │ … │
        │ r21 │ … │
        └─────┴───┘
        """,
        12 => """
        ┌─────┬────┐
        │ h1  │ h2 │
        ├─────┼────┤
        │ r11 │ r… │
        │ r21 │ r… │
        └─────┴────┘
        """,
        13 => """
        ┌─────┬─────┐
        │ h1  │ h2  │
        ├─────┼─────┤
        │ r11 │ r12 │
        │ r21 │ r22 │
        └─────┴─────┘
        """,
        99 => """
        ┌─────┬─────┐
        │ h1  │ h2  │
        ├─────┼─────┤
        │ r11 │ r12 │
        │ r21 │ r22 │
        └─────┴─────┘
        """
      }
      |> Enum.each(fn {max_width, expected_result} ->
        assert_tables_equal(
          [
            %{"h1" => "r11", "h2" => "r12"},
            %{"h1" => "r21", "h2" => "r22"}
          ],
          [max_width: max_width, truncate_lines: true, padding_x: 1],
          expected_result
        )
      end)
    end

    test "word_wrap" do
      assert_tables_equal(
        [%{"a" => "Hello, my name is Artur."}],
        [
          max_width: 9,
          divide_body_rows: true,
          word_wrap: :break_word
        ],
        """
        ┌───────┐
        │a      │
        ├───────┤
        │Hello, │
        │my name│
        │ is Art│
        │ur.    │
        └───────┘
        """
      )

      assert_tables_equal(
        [%{"a" => "Hello, my name is Artur."}],
        [
          max_width: 9,
          divide_body_rows: true,
          word_wrap: :normal
        ],
        """
        ┌───────┐
        │a      │
        ├───────┤
        │Hello, │
        │my name│
        │is     │
        │Artur. │
        └───────┘
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
