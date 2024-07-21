defmodule Owl.TrueColor do
  @moduledoc """
  A module for true color escape sequences

  ## Example

      "Hello"
      |> Owl.Data.tag([Owl.TrueColor.color(1, 244, 74), Owl.TrueColor.color_background(133, 48, 100)])
      |> Owl.IO.puts()
  """

  @doc ~S"""
  Returns a true color foreground escape sequence for the given RGB values.

  ## Example

      iex> Owl.TrueColor.color(1, 244, 74)
      "\e[38;2;1;244;74m"
  """
  @spec color(0..255, 0..255, 0..255) :: String.t()
  def color(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    "\e[38;2;#{r};#{g};#{b}m"
  end

  @doc ~S"""
  Returns a true color background escape sequence for the given RGB values.

  ## Example
      iex> Owl.TrueColor.color_background(133, 48, 100)
      "\e[48;2;133;48;100m"
  """
  @spec color_background(0..255, 0..255, 0..255) :: String.t()
  def color_background(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    "\e[48;2;#{r};#{g};#{b}m"
  end
end
