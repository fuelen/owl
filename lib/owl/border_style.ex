defmodule Owl.BorderStyle do
  @moduledoc false

  @border_styles %{
    solid: %{
      cross: "┼",
      top_cross: "┬",
      top_left: "┌",
      left_cross: "├",
      horizontal: "─",
      top_right: "┐",
      right_cross: "┤",
      vertical: "│",
      bottom_left: "└",
      bottom_cross: "┴",
      bottom_right: "┘"
    },
    solid_rounded: %{
      cross: "┼",
      top_left: "╭",
      top_cross: "┬",
      left_cross: "├",
      horizontal: "─",
      top_right: "╮",
      right_cross: "┤",
      vertical: "│",
      bottom_left: "╰",
      bottom_cross: "┴",
      bottom_right: "╯"
    },
    double: %{
      cross: "╬",
      top_left: "╔",
      top_cross: "╦",
      left_cross: "╠",
      horizontal: "═",
      top_right: "╗",
      right_cross: "╣",
      vertical: "║",
      bottom_left: "╚",
      bottom_cross: "╩",
      bottom_right: "╝"
    }
  }

  def fetch!(style_name) do
    Map.fetch!(@border_styles, style_name)
  end
end
