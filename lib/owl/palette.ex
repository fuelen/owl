defmodule Owl.Palette do
  @moduledoc """
  Poor man's color picker
  """
  @demo_block "████"

  @doc """
  Returns palette with named codes.

      Owl.Palette.named() |> Owl.IO.puts()

  Selected color can be used as follows

      # print "test" using cyan foreground color
      "test" |> Owl.Tag.new(:cyan) |> Owl.IO.puts

      # print "test" using light_green foreground color
      "test" |> Owl.Tag.new(:light_green) |> Owl.IO.puts

      # print "test" using light_green background color
      "test" |> Owl.Tag.new(:light_green_background) |> Owl.IO.puts

  """
  @spec named :: Owl.Data.t()
  def named do
    [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]
    |> Enum.map(fn color ->
      light_color = :"light_#{color}"

      [
        Owl.Tag.new(@demo_block, color), " #{String.pad_trailing(to_string(color), 13)}",
        Owl.Tag.new(@demo_block, light_color),
        " #{String.pad_trailing(to_string(light_color), 13)}    "
      ]
    end)
    |> Enum.intersperse("\n")
  end

  @doc """
  Returns palette with codes from 0 to 255.

      Owl.Palette.codes() |> Owl.IO.puts()

  Selected color can be used as follows

      # print "test" using foreground color with code 161
      "test" |> Owl.Tag.new(IO.ANSI.color(161)) |> Owl.IO.puts

      # print "test" using background color with code 161
      "test" |> Owl.Tag.new(IO.ANSI.color_background(161)) |> Owl.IO.puts
  """
  @spec codes :: Owl.Data.t()
  def codes do
    0..255
    |> Enum.map(fn code ->
      [
        Owl.Tag.new(@demo_block, IO.ANSI.color(code)),
        " #{String.pad_leading(to_string(code), 3)}    "
      ]
    end)
    |> Enum.chunk_every(30)
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.intersperse("\n")
  end

  @doc """
  Returns palette with individual RGB values.

      Owl.Palette.rgb() |> Owl.IO.puts()

  Selected color can be used as follows

      # print "test" using foreground color RGB(4, 3, 2)
      "test" |> Owl.Tag.new(IO.ANSI.color(4, 3, 2)) |> Owl.IO.puts

      # print "test" using background color RGB(4, 3, 2)
      "test" |> Owl.Tag.new(IO.ANSI.color_background(4, 3, 2)) |> Owl.IO.puts
  """
  @spec rgb :: Owl.Data.t()
  def rgb do
    0..5
    |> Enum.map(fn r ->
      0..5
      |> Enum.map(fn g ->
        0..5
        |> Enum.map(fn b ->
          [Owl.Tag.new(@demo_block, IO.ANSI.color(r, g, b)), " RGB(#{r}, #{g}, #{b})    "]
        end)
        |> Enum.intersperse("\n")
      end)
      |> Enum.reduce(&Owl.Data.zip/2)
    end)
    |> Enum.intersperse("\n")
  end
end
