defmodule Owl.Data.Sequence do
  @moduledoc false

  # CSI (Control Sequence Introducer)
  def parse_many("\e[" <> csi_params) do
    with {:ok, attributes} <- extract_csi_attributes(csi_params) do
      {:ok, attributes |> chunk_csi_attributes() |> Enum.map(&parse/1) |> Enum.reject(&is_nil/1)}
    end
  end

  # OSC (Operating System Command)
  # Hyperlink is the only supported OSC sequence for now.
  def parse_many("\e]8" <> _rest = binary) do
    case parse(binary) do
      nil -> :error
      sequence -> {:ok, [sequence]}
    end
  end

  def parse_many(_), do: :error

  defp extract_csi_attributes(csi_params) do
    csi_params
    |> String.split(";")
    |> Enum.reduce_while([], fn
      substring, acc ->
        case Integer.parse(substring) do
          :error -> {:halt, :error}
          {number, ""} -> {:cont, [number | acc]}
          {number, "m"} -> {:cont, [number | acc]}
          {_number, _rest} -> {:halt, :error}
        end
    end)
    |> case do
      :error -> :error
      attributes -> {:ok, Enum.reverse(attributes)}
    end
  end

  defp chunk_csi_attributes(attributes) do
    attributes
    |> chunk_csi_attributes([])
    |> Enum.reverse()
  end

  defp chunk_csi_attributes([lead_attribute, 5, n | tail], acc)
       when lead_attribute in [38, 48] do
    chunk_csi_attributes(tail, ["\e[#{lead_attribute};5;#{n}m" | acc])
  end

  defp chunk_csi_attributes([lead_attribute, 2, r, g, b | tail], acc)
       when lead_attribute in [38, 48] do
    chunk_csi_attributes(tail, ["\e[#{lead_attribute};2;#{r};#{g};#{b}m" | acc])
  end

  defp chunk_csi_attributes([head | tail], acc) do
    chunk_csi_attributes(tail, ["\e[#{head}m" | acc])
  end

  defp chunk_csi_attributes([], acc) do
    acc
  end

  @doc """
  Get the default value of a sequence type.
  """
  def default_value_by_type!(:foreground), do: :default_color
  def default_value_by_type!(:background), do: :default_background
  def default_value_by_type!(:blink), do: :blink_off
  def default_value_by_type!(:intensity), do: :normal
  def default_value_by_type!(:underline), do: :no_underline
  def default_value_by_type!(:italic), do: :not_italic
  def default_value_by_type!(:overlined), do: :not_overlined
  def default_value_by_type!(:inverse), do: :inverse_off
  def default_value_by_type!(:reverse), do: :reverse_off

  colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

  names =
    Enum.flat_map(colors, fn color ->
      [color, :"light_#{color}", :"#{color}_background", :"light_#{color}_background"]
    end) ++
      [
        :reset,
        :default_color,
        :default_background,
        :blink_off,
        :blink_slow,
        :blink_rapid,
        :normal,
        :faint,
        :bright,
        :inverse,
        # :reverse is omitted, because it has the same code as :inverse
        :underline,
        :no_underline,
        :italic,
        :not_italic,
        :overlined,
        :not_overlined
      ]

  for name <- names do
    binary = apply(IO.ANSI, name, [])
    def parse(unquote(binary)), do: unquote(name)
  end

  def parse("\e]8;" <> rest) do
    case String.split(rest, ";") do
      [_params, url_and_terminator] ->
        {:hyperlink, String.trim_trailing(url_and_terminator, "\e\\")}

      _ ->
        nil
    end
  end

  def parse("\e[38;5;" <> _ = binary), do: binary
  def parse("\e[48;5;" <> _ = binary), do: binary
  def parse("\e[38;2;" <> _ = binary), do: binary
  def parse("\e[48;2;" <> _ = binary), do: binary

  # nil for unsupported sequences
  def parse(_), do: nil

  for color <- colors do
    def type(unquote(color)), do: :foreground
    def type(unquote(:"light_#{color}")), do: :foreground
    def type(unquote(:"#{color}_background")), do: :background
    def type(unquote(:"light_#{color}_background")), do: :background
  end

  def type(:default_color), do: :foreground
  def type(:default_background), do: :background

  def type(:blink_off), do: :blink
  def type(:blink_slow), do: :blink
  def type(:blink_rapid), do: :blink

  def type(:normal), do: :intensity
  def type(:faint), do: :intensity
  def type(:bright), do: :intensity

  def type(:inverse), do: :inverse

  def type(:reverse), do: :reverse

  def type(:underline), do: :underline
  def type(:no_underline), do: :underline

  def type(:italic), do: :italic
  def type(:not_italic), do: :italic

  def type(:overlined), do: :overlined
  def type(:not_overlined), do: :overlined

  def type({:hyperlink, _url}), do: :hyperlink

  def type("\e[38;5;" <> _), do: :foreground
  def type("\e[48;5;" <> _), do: :background
  def type("\e[38;2;" <> _), do: :foreground
  def type("\e[48;2;" <> _), do: :background

  def open_hyperlink(url) when is_binary(url) do
    ["\e]8;id=", to_string(:erlang.phash2(url)), ";", url, "\e\\"]
  end

  def close_hyperlink do
    "\e]8;;\e\\"
  end
end
