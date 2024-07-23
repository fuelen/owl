defmodule Owl.BoxTest do
  use ExUnit.Case, async: true
  import Owl.Data.TestHelpers
  doctest Owl.Box

  describe inspect(&Owl.Box.new/2) do
    test "paddings" do
      assert "x" |> Owl.Box.new(padding: 3) |> to_string ==
               """
               ┌───────┐
               │       │
               │       │
               │       │
               │   x   │
               │       │
               │       │
               │       │
               └───────┘
               """
               |> String.trim_trailing()

      assert "x" |> Owl.Box.new(padding_x: 3) |> to_string ==
               """
               ┌───────┐
               │   x   │
               └───────┘
               """
               |> String.trim_trailing()

      assert "x" |> Owl.Box.new(padding_y: 3) |> to_string ==
               """
               ┌─┐
               │ │
               │ │
               │ │
               │x│
               │ │
               │ │
               │ │
               └─┘
               """
               |> String.trim_trailing()

      assert "x" |> Owl.Box.new(padding: 3, padding_right: 0) |> to_string ==
               """
               ┌────┐
               │    │
               │    │
               │    │
               │   x│
               │    │
               │    │
               │    │
               └────┘
               """
               |> String.trim_trailing()
    end

    test "max_width < min_width makes max_width equal to min_width" do
      assert "VeryLongLine" |> Owl.Box.new(max_width: 2, min_width: 10) |> to_string() ==
               """
               ┌────────┐
               │VeryLong│
               │Line    │
               └────────┘
               """
               |> String.trim_trailing()
    end

    test "min width includes padding size" do
      assert "i" |> Owl.Box.new(min_width: 5, padding_left: 2) |> to_string() ==
               """
               ┌───┐
               │  i│
               └───┘
               """
               |> String.trim_trailing()

      assert "i" |> Owl.Box.new(min_width: 5, padding_right: 2) |> to_string() ==
               """
               ┌───┐
               │i  │
               └───┘
               """
               |> String.trim_trailing()
    end

    test "min height includes padding size" do
      assert "i" |> Owl.Box.new(min_height: 5, padding_bottom: 2) |> to_string() ==
               """
               ┌─┐
               │i│
               │ │
               │ │
               └─┘
               """
               |> String.trim_trailing()

      assert "i" |> Owl.Box.new(min_height: 5, padding_top: 2) |> to_string() ==
               """
               ┌─┐
               │ │
               │ │
               │i│
               └─┘
               """
               |> String.trim_trailing()

      assert "i" |> Owl.Box.new(min_height: 5, padding_top: 5) |> to_string() ==
               """
               ┌─┐
               │ │
               │ │
               │ │
               │ │
               │ │
               │i│
               └─┘
               """
               |> String.trim_trailing()
    end

    test "correctly renders empty lines" do
      assert "foo\n\nbar" |> Owl.Box.new(max_width: 10) |> to_string() ==
               """
               ┌───┐
               │foo│
               │   │
               │bar│
               └───┘
               """
               |> String.trim_trailing()
    end

    test "title is too big" do
      assert_raise ArgumentError, fn ->
        Owl.Box.new("test", max_width: 5, title: "VeryLongLine")
      end
    end

    test "border requires more space than max_width" do
      assert_raise ArgumentError,
                   "`:max_width` must be at least 2 when `:border_style` is not `:none`, got: 1",
                   fn ->
                     Owl.Box.new("test", max_width: 1)
                   end

      assert "test" |> Owl.Box.new(max_width: 1, border_style: :none) |> to_string() ==
               """
               t
               e
               s
               t
               """
               |> String.trim_trailing()
    end

    test "render borders only if max_width is 2 and `border_style` is not :none" do
      assert "" |> Owl.Box.new(max_width: 2) |> to_string() ==
               """
               ┌┐
               ││
               └┘
               """
               |> String.trim_trailing()

      assert "test\ntest" |> Owl.Box.new(max_width: 2) |> to_string() ==
               """
               ┌┐
               ││
               ││
               └┘
               """
               |> String.trim_trailing()
    end

    test "borders style" do
      assert "test" |> Owl.Box.new(border_style: :solid_rounded) |> to_string() ==
               """
               ╭────╮
               │test│
               ╰────╯
               """
               |> String.trim_trailing()
    end

    test "truncate lines" do
      assert "test\ntest" |> Owl.Box.new(max_width: 5, truncate_lines: true) |> to_string() ==
               """
               ┌───┐
               │te…│
               │te…│
               └───┘
               """
               |> String.trim_trailing()
    end

    test "wrap_word" do
      get_wrapped_lines = fn data, max_width ->
        data
        |> Owl.Box.new(max_width: max_width, word_wrap: :normal, border_style: :none)
        |> to_string()
        |> Owl.Data.lines()
      end

      assert get_wrapped_lines.("Hello! My name is Artur.", 2) == [
               "He",
               "ll",
               "o!",
               "My",
               "na",
               "me",
               "is",
               "Ar",
               "tu",
               "r."
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 3) == [
               "Hel",
               "lo!",
               "My ",
               "nam",
               "e  ",
               "is ",
               "Art",
               "ur."
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 4) == [
               "Hell",
               "o!  ",
               "My  ",
               "name",
               "is A",
               "rtur",
               ".   "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 5) == [
               "Hello",
               "! My ",
               "name ",
               "is Ar",
               "tur. "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 6) == [
               "Hello!",
               "My    ",
               "name  ",
               "is    ",
               "Artur."
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 7) == [
               "Hello! ",
               "My name",
               "is     ",
               "Artur. "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 8) == [
               "Hello! ",
               "My name",
               "is     ",
               "Artur. "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 9) == [
               "Hello! My",
               "name is  ",
               "Artur.   "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 10) == [
               "Hello! My",
               "name is  ",
               "Artur.   "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 11) == [
               "Hello! My",
               "name is  ",
               "Artur.   "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 12) == [
               "Hello! My",
               "name is  ",
               "Artur.   "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 13) == [
               "Hello! My",
               "name is  ",
               "Artur.   "
             ]

      assert get_wrapped_lines.("Hello! My name is Artur.", 14) == [
               "Hello! My name",
               "is Artur.     "
             ]

      assert [Owl.Data.tag("Hi there!", :red), " Hi", [Owl.Data.tag("!!!", :green)]]
             |> Owl.Box.new(max_width: 6, word_wrap: :normal, border_style: :none)
             |> Owl.Data.to_chardata()
             |> Owl.Data.from_chardata()
             |> List.flatten() == [
               Owl.Data.tag("Hi", :red),
               "    \n",
               Owl.Data.tag("there!", :red),
               "\nHi",
               Owl.Data.tag("!!!", :green),
               " "
             ]

      # It would be great if spaces are tagged as well in output result, but this is not implemented yet.
      # This test is present just to track this issue.
      assert "A B C"
             |> Owl.Data.tag([:red, :green_background])
             |> Owl.Box.new(word_wrap: :normal, border_style: :none, max_width: 80)
             |> Owl.Data.to_chardata()
             |> Owl.Data.from_chardata()
             <~> [
               Owl.Data.tag("A", [:green_background, :red]),
               " ",
               Owl.Data.tag("B", [:green_background, :red]),
               " ",
               Owl.Data.tag("C", [:green_background, :red])
             ]
    end
  end
end
