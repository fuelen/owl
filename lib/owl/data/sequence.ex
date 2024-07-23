defmodule Owl.Data.Sequence.DSL do
  @moduledoc false

  defmacro defsequence_type(name, type, define_name_by_sequence? \\ true) do
    quote bind_quoted: [
            name: name,
            type: type,
            define_name_by_sequence?: define_name_by_sequence?
          ] do
      if define_name_by_sequence? do
        seq = apply(IO.ANSI, name, [])
        defp name_by_sequence(unquote(seq)), do: unquote(name)
      end

      defp type_by_name(unquote(name)), do: unquote(type)
    end
  end
end

defmodule Owl.Data.Sequence do
  @moduledoc false

  import Owl.Data.Sequence.DSL

  def split(string) do
    with {:ok, attributes} <- extract_display_attributes(string) do
      {:ok, chunk_attributes(attributes)}
    end
  end

  defp extract_display_attributes("\e[" <> rest) do
    rest
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

  defp extract_display_attributes(_), do: :error

  defp chunk_attributes(attributes) do
    attributes
    |> chunk_attributes([])
    |> Enum.reverse()
  end

  defp chunk_attributes([lead_attribute, 5, n | tail], acc)
       when lead_attribute in [38, 48] do
    chunk_attributes(tail, ["\e[#{lead_attribute};5;#{n}m" | acc])
  end

  defp chunk_attributes([lead_attribute, 2, r, g, b | tail], acc)
       when lead_attribute in [38, 48] do
    chunk_attributes(tail, ["\e[#{lead_attribute};2;#{r};#{g};#{b}m" | acc])
  end

  defp chunk_attributes([head | tail], acc) do
    chunk_attributes(tail, ["\e[#{head}m" | acc])
  end

  defp chunk_attributes([], acc) do
    acc
  end

  @doc """
  Try to convert binary sequence to a sequence name.

  Returns binary if escape sequence is for colors.
  Returns name as an atom if a sequence is supported.
  Returns nil if the sequence is not supported.
  """
  def binary_to_name(binary) when is_binary(binary) do
    case binary do
      "\e[38;5;" <> _ -> binary
      "\e[48;5;" <> _ -> binary
      "\e[38;2;" <> _ -> binary
      "\e[48;2;" <> _ -> binary
      _ -> name_by_sequence(binary)
    end
  end

  @doc """
  Get the sequence type of a sequence name.
  """
  def type!(sequence) when is_atom(sequence), do: type_by_name(sequence)
  def type!("\e[38;5;" <> _), do: :foreground
  def type!("\e[48;5;" <> _), do: :background
  def type!("\e[38;2;" <> _), do: :foreground
  def type!("\e[48;2;" <> _), do: :background

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

  defsequence_type(:reset, :reset)

  for color <- [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white] do
    defsequence_type(color, :foreground)
    defsequence_type(:"light_#{color}", :foreground)
    defsequence_type(:"#{color}_background", :background)
    defsequence_type(:"light_#{color}_background", :background)
  end

  defsequence_type(:default_color, :foreground)
  defsequence_type(:default_background, :background)

  defsequence_type(:blink_off, :blink)
  defsequence_type(:blink_slow, :blink)
  defsequence_type(:blink_rapid, :blink)

  defsequence_type(:normal, :intensity)
  defsequence_type(:faint, :intensity)
  defsequence_type(:bright, :intensity)

  defsequence_type(:inverse, :inverse)
  defsequence_type(:reverse, :reverse, false)

  defsequence_type(:underline, :underline)
  defsequence_type(:no_underline, :underline)

  defsequence_type(:italic, :italic)
  defsequence_type(:not_italic, :italic)

  defsequence_type(:overlined, :overlined)
  defsequence_type(:not_overlined, :overlined)

  defp name_by_sequence(_), do: nil
end
