defmodule Owl.BoxTest do
  use ExUnit.Case, async: true
  doctest Owl.Box

  describe inspect(&Owl.Box.new/2) do
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

    test "title is too big" do
      assert_raise ArgumentError, fn ->
        Owl.Box.new("test", max_width: 5, title: "VeryLongLine")
      end
    end
  end
end
