defmodule Owl.BoxTest do
  use ExUnit.Case, async: true
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

    test "borders style" do
      assert "test" |> Owl.Box.new(border_style: :solid_rounded) |> to_string() ==
               """
               ╭────╮
               │test│
               ╰────╯
               """
               |> String.trim_trailing()
    end
  end
end
