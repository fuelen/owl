defmodule Owl.Data do
  @moduledoc """
  A set of functions for `t:iodata/0` with tags.
  """

  @typedoc """
  A recursive data type that is similar to  `t:iodata/0`, but additionally supports `t:Owl.Tag.t/1`.

  Can be written to stdout using `Owl.IO.puts/1`.
  """
  # improper lists are now here, just because they were not tested
  @type t :: [binary() | number() | t() | Owl.Tag.t(t())] | Owl.Tag.t(t()) | binary()

  @doc """
  Zips corresponding lines into 1 line.

  The zipping finishes as soon as either data completes.

  ## Examples

      iex> Owl.Data.zip("a\\nb\\nc", "d\\ne\\nf")
      [["a", "d"], "\\n", ["b", "e"], "\\n", ["c", "f"]]

      iex> Owl.Data.zip("a\\nb", "c")
      [["a", "c"]]

      iex> 1..3 |> Enum.map(&Owl.Box.new/1) |> Enum.reduce(&Owl.Data.zip/2) |> to_string()
      \"""
      ┌─┐┌─┐┌─┐
      │3││2││1│
      └─┘└─┘└─┘
      \""" |> String.trim_trailing()
  """
  @spec zip(t(), t()) :: t()
  def zip(data1, data2) do
    lines1 = lines(data1)
    lines2 = lines(data2)

    lines1
    |> Enum.zip_with(lines2, &[&1, &2])
    |> unlines()
  end

  @doc """
  Returns length of the data.

  ## Examples

      iex> Owl.Data.length(321)
      3

      iex> Owl.Data.length(["222"])
      3

      iex> Owl.Data.length(["222", Owl.Tag.new(["333", "444"], :green)])
      9
  """
  @spec length(t()) :: non_neg_integer()
  def length(data) when is_binary(data) do
    String.length(data)
  end

  def length(data) when is_number(data) do
    Owl.Data.length(to_string(data))
  end

  def length(data) when is_list(data) do
    Enum.reduce(data, 0, fn item, acc -> Owl.Data.length(item) + acc end)
  end

  def length(%Owl.Tag{data: data}) do
    Owl.Data.length(data)
  end

  @doc """
  Splits data by new lines.

  A special case of `split/2`.

  ## Example

      iex> Owl.Data.lines(["first\\nsecond\\n", Owl.Tag.new("third\\nfourth", :red)])
      ["first", "second", Owl.Tag.new(["third"], :red), Owl.Tag.new(["fourth"], :red)]
  """
  @spec lines(t()) :: [t()]
  def lines(data) do
    split(data, "\n")
  end

  def unlines(data) do
    Enum.intersperse(data, "\n")
  end

  @doc """
  Adds a `prefix` before each line of the `data`.

  An important feature is that styling of the data will be saved for each line.

  ## Example

      iex> "first\\nsecond" |> Owl.Tag.new(:red) |> Owl.Data.add_prefix(Owl.Tag.new("test: ", :yellow))
      [
        [Owl.Tag.new("test: ", :yellow), Owl.Tag.new(["first"], :red)],
        "\\n",
        [Owl.Tag.new("test: ", :yellow), Owl.Tag.new(["second"], :red)]
      ]
  """
  @spec add_prefix(t(), t()) :: t()
  def add_prefix(data, prefix) do
    data
    |> lines()
    |> Enum.map(fn line -> [prefix, line] end)
    |> unlines()
  end

  @doc """
  Transforms data to `t:IO.ANSI.ansidata/0` format which can be consumed by `IO` module.

  ## Examples

      iex> "hello" |> Owl.Tag.new([:red, :cyan_background]) |> Owl.Data.to_ansidata()
      [[[[[[[] | "\e[46m"] | "\e[31m"], "hello"] | "\e[39m"] | "\e[49m"] | "\e[0m"]

  """
  @spec to_ansidata(t()) :: IO.ANSI.ansidata()
  def to_ansidata(data) do
    # split by \n and then intersperse is needed in order to break background and do not spread to the end of the line
    data
    |> lines()
    |> unlines()
    |> do_to_ansidata(%{foreground: :default_color, background: :default_background})
    |> IO.ANSI.format()
  end

  defp do_to_ansidata(
         %Owl.Tag{sequences: sequences, data: data},
         %{foreground: fg, background: bg}
       ) do
    parent_sequences = Enum.reject([fg, bg], &is_nil/1)

    [
      sequences,
      do_to_ansidata(data, sequences_to_state(parent_sequences ++ sequences)),
      parent_sequences
    ]
  end

  defp do_to_ansidata([head | tail], state) do
    [do_to_ansidata(head, state) | do_to_ansidata(tail, state)]
  end

  defp do_to_ansidata(term, _state), do: term

  defp maybe_wrap_to_tag([], [element]), do: element
  defp maybe_wrap_to_tag([], data), do: data

  defp maybe_wrap_to_tag(sequences1, [%Owl.Tag{sequences: sequences2, data: data}]) do
    Owl.Tag.new(data, collapse_sequences(sequences1 ++ sequences2))
  end

  defp maybe_wrap_to_tag(sequences, data) do
    Owl.Tag.new(data, collapse_sequences(sequences))
  end

  defp reverse_and_tag(sequences, [%Owl.Tag{sequences: last_sequences} | _] = data) do
    maybe_wrap_to_tag(sequences -- last_sequences, Enum.reverse(data))
  end

  defp reverse_and_tag(sequences, data) do
    maybe_wrap_to_tag(sequences, Enum.reverse(data))
  end

  # last write wins
  defp collapse_sequences(sequences) do
    sequences
    |> sequences_to_state()
    |> Map.values()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Divides data into parts based on a pattern saving sequences for tagged data in new tags.

  ## Example

      iex> Owl.Data.split(["first second ", Owl.Tag.new("third fourth", :red)], " ")
      ["first", "second", Owl.Tag.new(["third"], :red), Owl.Tag.new(["fourth"], :red)]
  """
  def split(data, pattern), do: split(data, pattern, [])
  defp split([], _pattern, _acc_sequences), do: []

  defp split(data, pattern, acc_sequences) do
    case do_split(data, pattern, [], acc_sequences) do
      {before_pattern, after_pattern, []} ->
        [
          reverse_and_tag(acc_sequences, before_pattern)
          | split(after_pattern, pattern, acc_sequences)
        ]

      {before_pattern, after_pattern, next_acc_sequences} ->
        [
          reverse_and_tag(acc_sequences ++ next_acc_sequences, before_pattern)
          | split(after_pattern, pattern, next_acc_sequences)
        ]
    end
  end

  defp do_split([head | tail], pattern, acc, acc_sequences) do
    case do_split(head, pattern, acc, acc_sequences) do
      {new_head, [], new_acc_sequences} ->
        do_split(tail, pattern, new_head, new_acc_sequences)

      {new_head, new_tail, new_acc_sequences} ->
        new_tail = maybe_wrap_to_tag(new_acc_sequences -- acc_sequences, new_tail)

        new_acc_sequences =
          case new_head do
            [%Owl.Tag{sequences: sequences} | _] -> new_acc_sequences -- sequences
            _ -> new_acc_sequences
          end

        new_head =
          case new_head do
            [%Owl.Tag{data: []} | rest] -> rest
            list -> list
          end

        {new_head, [new_tail | tail], new_acc_sequences}
    end
  end

  defp do_split([], _pattern, acc, acc_sequences) do
    {acc, [], acc_sequences}
  end

  defp do_split(
         %Owl.Tag{sequences: sequences, data: data},
         pattern,
         acc,
         acc_sequences
       ) do
    {before_pattern, after_pattern, next_acc_sequences} =
      do_split(data, pattern, [], acc_sequences ++ sequences)

    before_pattern = reverse_and_tag(sequences, before_pattern)

    next_acc_sequences =
      case {before_pattern, after_pattern} do
        {%Owl.Tag{sequences: sequences}, []} -> next_acc_sequences -- sequences
        {_, []} -> acc_sequences
        {_, _} -> next_acc_sequences
      end

    {[before_pattern | acc], after_pattern, next_acc_sequences}
  end

  defp do_split(value, pattern, acc, acc_sequences) when is_binary(value) do
    [head | tail] = String.split(value, pattern, parts: 2)

    {
      case head do
        "" -> acc
        value -> [value | acc]
      end,
      tail,
      acc_sequences
    }
  end

  defp do_split(value, pattern, acc, acc_sequences) when is_number(value) do
    do_split(to_string(value), pattern, acc, acc_sequences)
  end

  defp sequences_to_state(sequences) do
    Enum.reduce(sequences, %{foreground: nil, background: nil}, fn sequence, acc ->
      Map.put(acc, sequence_type(sequence), sequence)
    end)
  end

  for color <- [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white] do
    defp sequence_type(unquote(color)), do: :foreground
    defp sequence_type(unquote(:"light_#{color}")), do: :foreground
    defp sequence_type(unquote(:"#{color}_background")), do: :background
    defp sequence_type(unquote(:"light_#{color}_background")), do: :background
  end

  defp sequence_type(:default_color), do: :foreground
  defp sequence_type(:default_background), do: :background

  # https://github.com/elixir-lang/elixir/blob/74bfab8ee271e53d24cb0012b5db1e2a931e0470/lib/elixir/lib/io/ansi.ex#L73
  defp sequence_type("\e[38;5;" <> _), do: :foreground

  # https://github.com/elixir-lang/elixir/blob/74bfab8ee271e53d24cb0012b5db1e2a931e0470/lib/elixir/lib/io/ansi.ex#L87
  defp sequence_type("\e[48;5;" <> _), do: :background
end
