defmodule Owl.Data do
  @moduledoc """
  A set of functions for `t:iodata/0` with tags.
  """

  @typedoc """
  A recursive data type that is similar to  `t:iodata/0`, but additionally supports `t:Owl.Tag.t/1`.

  Can be written to stdout using `Owl.IO.puts/2`.
  """
  # improper lists are not here, just because they were not tested
  @type t :: [binary() | non_neg_integer() | t() | Owl.Tag.t(t())] | Owl.Tag.t(t()) | binary()

  @typedoc """
  ANSI escape sequence.

  An atom alias of ANSI escape sequence.

  A binary representation of color like `"\e[38;5;33m"` (which is `IO.ANSI.color(33)` or `IO.ANSI.color(0, 2, 5)`).
  """
  @type sequence ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | :black_background
          | :red_background
          | :green_background
          | :yellow_background
          | :blue_background
          | :magenta_background
          | :cyan_background
          | :white_background
          | :light_black_background
          | :light_red_background
          | :light_green_background
          | :light_yellow_background
          | :light_blue_background
          | :light_magenta_background
          | :light_cyan_background
          | :light_white_background
          | :default_color
          | :default_background
          | :blink_slow
          | :blink_rapid
          | :faint
          | :bright
          | :inverse
          | :underline
          | :italic
          | :overlined
          | :reverse
          | binary()

  @doc """
  Builds a tag.

  ## Examples

      iex> Owl.Data.tag(["hello ", Owl.Data.tag("world", :green), "!!!"], :red) |> inspect()
      ~s|#Owl.Tag[:red]<["hello ", #Owl.Tag[:green]<"world">, "!!!"]>|

      iex> Owl.Data.tag("hello world", [:green, :red_background]) |> inspect()
      ~s|#Owl.Tag[:green, :red_background]<"hello world">|
  """
  @spec tag(data, sequence() | [sequence()]) :: Owl.Tag.t(data) when data: t()
  def tag(data, sequence_or_sequences) do
    %Owl.Tag{
      sequences: List.wrap(sequence_or_sequences),
      data: data
    }
  end

  @doc """
  Removes information about sequences and keeps only content of the tag.

  ## Examples

      iex> Owl.Data.tag("Hello", :red) |> Owl.Data.untag()
      "Hello"

      iex> Owl.Data.tag([72, 101, 108, 108, 111], :red) |> Owl.Data.untag()
      'Hello'

      iex> ["Hello ", Owl.Data.tag("world", :red), "!"] |> Owl.Data.untag()
      ["Hello ", "world", "!"]
  """
  @spec untag(t()) :: iodata()
  def untag(data) when is_list(data) do
    Enum.map(data, &untag_child/1)
  end

  def untag(%Owl.Tag{data: data}) do
    data
  end

  def untag(data) when is_binary(data) do
    data
  end

  defp untag_child(data) when is_list(data) do
    Enum.map(data, &untag_child/1)
  end

  defp untag_child(%Owl.Tag{data: data}) do
    data
  end

  defp untag_child(data) when is_binary(data) do
    data
  end

  defp untag_child(data) when is_integer(data) do
    data
  end

  @doc """
  Zips corresponding lines into 1 line.

  The zipping finishes as soon as either data completes.

  ## Examples

      iex> Owl.Data.zip("a\\nb\\nc", "d\\ne\\nf")
      [["a", "d"], "\\n", ["b", "e"], "\\n", ["c", "f"]]

      iex> Owl.Data.zip("a\\nb", "c")
      [["a", "c"]]

      iex> 1..3
      ...> |> Enum.map(&to_string/1)
      ...> |> Enum.map(&Owl.Box.new/1) |> Enum.reduce(&Owl.Data.zip/2) |> to_string()
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

      iex> Owl.Data.length(["222"])
      3

      iex> Owl.Data.length([222])
      1

      iex> Owl.Data.length([[[]]])
      0

      iex> Owl.Data.length(["222", Owl.Data.tag(["333", "444"], :green)])
      9
  """
  @spec length(t()) :: non_neg_integer()
  def length(data) when is_binary(data) do
    String.length(data)
  end

  def length(data) when is_list(data) do
    import Kernel, except: [length: 1]

    Enum.reduce(data, 0, fn
      item, acc when is_integer(item) -> length(<<item::utf8>>) + acc
      item, acc -> length(item) + acc
    end)
  end

  def length(%Owl.Tag{data: data}) do
    import Kernel, except: [length: 1]
    length(data)
  end

  @doc """
  Splits data by new lines.

  A special case of `split/2`.

  ## Example

      iex> Owl.Data.lines(["first\\nsecond\\n", Owl.Data.tag("third\\nfourth", :red)])
      ["first", "second", Owl.Data.tag(["third"], :red), Owl.Data.tag(["fourth"], :red)]
  """
  @spec lines(t()) :: [t()]
  def lines(data) do
    split(data, "\n")
  end

  @doc """
  Creates a `t:t/0` from an a list of `t:t/0`, it inserts new line characters between original elements.

  ## Examples

      iex> Owl.Data.unlines(["a", "b", "c"])
      ["a", "\\n", "b", "\\n", "c"]

      iex> ["first\\nsecond\\n", Owl.Data.tag("third\\nfourth", :red)]
      ...> |> Owl.Data.lines()
      ...> |> Owl.Data.unlines()
      ...> |> Owl.Data.to_ansidata()
      Owl.Data.to_ansidata(["first\\nsecond\\n", Owl.Data.tag("third\\nfourth", :red)])
  """
  @spec unlines([t()]) :: [t()]
  def unlines(data) do
    Enum.intersperse(data, "\n")
  end

  @doc """
  Adds a `prefix` before each line of the `data`.

  An important feature is that styling of the data will be saved for each line.

  ## Example

      iex> "first\\nsecond" |> Owl.Data.tag(:red) |> Owl.Data.add_prefix(Owl.Data.tag("test: ", :yellow))
      [
        [Owl.Data.tag("test: ", :yellow), Owl.Data.tag(["first"], :red)],
        "\\n",
        [Owl.Data.tag("test: ", :yellow), Owl.Data.tag(["second"], :red)]
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

      iex> "hello" |> Owl.Data.tag([:red, :cyan_background]) |> Owl.Data.to_ansidata()
      [[[[[[[] | "\e[46m"] | "\e[31m"], "hello"] | "\e[39m"] | "\e[49m"] | "\e[0m"]

  """
  @spec to_ansidata(t()) :: IO.ANSI.ansidata()
  def to_ansidata(data) do
    # split by \n and then intersperse is needed in order to break background and do not spread to the end of the line
    data
    |> lines()
    |> unlines()
    |> do_to_ansidata(%{})
    |> IO.ANSI.format()
  end

  defp do_to_ansidata(
         %Owl.Tag{sequences: sequences, data: data},
         open_tags
       ) do
    new_open_tags = sequences_to_state(open_tags, sequences)

    close_tags =
      Enum.reduce(new_open_tags, [], fn {sequence_type, sequence}, acc ->
        case Map.get(open_tags, sequence_type) do
          nil ->
            return_to = default_value_by_sequence_type(sequence_type)

            [return_to | acc]

          previous_sequence ->
            if previous_sequence == sequence do
              acc
            else
              [previous_sequence | acc]
            end
        end
      end)

    [sequences, do_to_ansidata(data, new_open_tags), close_tags]
  end

  defp do_to_ansidata(list, open_tags) when is_list(list) do
    Enum.map(list, &do_to_ansidata(&1, open_tags))
  end

  defp do_to_ansidata(term, _open_tags), do: term

  defp maybe_wrap_to_tag([], [element]), do: element
  defp maybe_wrap_to_tag([], data), do: data

  defp maybe_wrap_to_tag(sequences1, [%Owl.Tag{sequences: sequences2, data: data}]) do
    tag(data, collapse_sequences(sequences1 ++ sequences2))
  end

  defp maybe_wrap_to_tag(sequences, data) do
    tag(data, collapse_sequences(sequences))
  end

  defp reverse_and_tag(sequences, [%Owl.Tag{sequences: last_sequences} | _] = data) do
    maybe_wrap_to_tag(sequences -- last_sequences, Enum.reverse(data))
  end

  defp reverse_and_tag(sequences, data) do
    maybe_wrap_to_tag(sequences, Enum.reverse(data))
  end

  # last write wins
  defp collapse_sequences(sequences) do
    %{foreground: nil, background: nil}
    |> sequences_to_state(sequences)
    |> Map.values()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Divides data into parts based on a pattern saving sequences for tagged data in new tags.

  ## Example

      iex> Owl.Data.split(["first second ", Owl.Data.tag("third fourth", :red)], " ")
      ["first", "second", Owl.Data.tag(["third"], :red), Owl.Data.tag(["fourth"], :red)]

      iex> Owl.Data.split(["first   second ", Owl.Data.tag("third    fourth", :red)], ~r/\s+/)
      ["first", "second", Owl.Data.tag(["third"], :red), Owl.Data.tag(["fourth"], :red)]
  """
  @spec split(t(), String.pattern() | Regex.t()) :: [t()]
  def split(data, pattern) do
    chunk_by(
      data,
      pattern,
      fn value, pattern ->
        [head | tail] = String.split(value, pattern, parts: 2)

        head = if head == "", do: [], else: head
        resolution = if tail == [], do: :cont, else: :chunk

        {resolution, pattern, head, tail}
      end
    )
  end

  defp sequences_to_state(init, sequences) do
    Enum.reduce(sequences, init, fn sequence, acc ->
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

  defp sequence_type(:blink_slow), do: :blink
  defp sequence_type(:blink_rapid), do: :blink
  defp sequence_type(:faint), do: :intensity
  defp sequence_type(:bright), do: :intensity
  defp sequence_type(:inverse), do: :inverse
  defp sequence_type(:underline), do: :underline
  defp sequence_type(:italic), do: :italic
  defp sequence_type(:overlined), do: :overlined
  defp sequence_type(:reverse), do: :reverse

  # https://github.com/elixir-lang/elixir/blob/74bfab8ee271e53d24cb0012b5db1e2a931e0470/lib/elixir/lib/io/ansi.ex#L73
  defp sequence_type("\e[38;5;" <> _), do: :foreground

  # https://github.com/elixir-lang/elixir/blob/74bfab8ee271e53d24cb0012b5db1e2a931e0470/lib/elixir/lib/io/ansi.ex#L87
  defp sequence_type("\e[48;5;" <> _), do: :background

  defp default_value_by_sequence_type(:foreground), do: :default_color
  defp default_value_by_sequence_type(:background), do: :default_background
  defp default_value_by_sequence_type(:blink), do: :blink_off
  defp default_value_by_sequence_type(:intensity), do: :normal
  defp default_value_by_sequence_type(:inverse), do: :inverse_off
  defp default_value_by_sequence_type(:underline), do: :no_underline
  defp default_value_by_sequence_type(:italic), do: :not_italic
  defp default_value_by_sequence_type(:overlined), do: :not_overlined
  defp default_value_by_sequence_type(:reverse), do: :reverse_off

  @doc """
  Returns list of `t()` containing `count` elements each.

  ## Example

      iex> Owl.Data.chunk_every(
      ...>   ["first second ", Owl.Data.tag(["third", Owl.Data.tag(" fourth", :blue)], :red)],
      ...>   7
      ...> )
      [
        "first s",
        ["econd ", Owl.Data.tag(["t"], :red)],
        Owl.Data.tag(["hird", Owl.Data.tag([" fo"], :blue)], :red),
        Owl.Data.tag(["urth"], :blue)
      ]
  """
  @spec chunk_every(data :: t(), count :: pos_integer()) :: [t()]
  def chunk_every(data, count) when count > 0 do
    chunk_by(
      data,
      {0, count},
      fn value, {cut_left, count} ->
        split_at = if cut_left == 0, do: count, else: cut_left

        case String.split_at(value, split_at) do
          {head, ""} ->
            left = split_at - String.length(head)
            resolution = if left == 0, do: :chunk, else: :cont

            {resolution, {left, count}, head, []}

          {head, rest} ->
            {:chunk, {0, count}, head, [rest]}
        end
      end
    )
  end

  defp chunk_by(data, chunk_acc, chunk_fun), do: chunk_by(data, chunk_acc, chunk_fun, [])
  defp chunk_by([], _chunk_acc, _chunk_fun, _acc_sequences), do: []

  defp chunk_by(data, chunk_acc, chunk_fun, acc_sequences) do
    {_, before_pattern, after_pattern, chunk_acc, next_acc_sequences} =
      do_chunk_by(data, chunk_acc, chunk_fun, [], acc_sequences)

    [
      reverse_and_tag(acc_sequences ++ next_acc_sequences, before_pattern)
      | chunk_by(after_pattern, chunk_acc, chunk_fun, next_acc_sequences)
    ]
  end

  defp do_chunk_by([head | tail], chunk_acc, chunk_fun, acc, acc_sequences) do
    case do_chunk_by(head, chunk_acc, chunk_fun, acc, acc_sequences) do
      {:cont, new_head, new_tail, chunk_acc, new_acc_sequences} ->
        new_tail
        |> put_nonempty_head(tail)
        |> do_chunk_by(chunk_acc, chunk_fun, new_head, new_acc_sequences)

      {:chunk, new_head, new_tail, chunk_acc, new_acc_sequences} ->
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

        new_tail = put_nonempty_head(new_tail, tail)

        {:chunk, new_head, new_tail, chunk_acc, new_acc_sequences}
    end
  end

  defp do_chunk_by([], chunk_acc, _chunk_fun, acc, acc_sequences) do
    {:cont, acc, [], chunk_acc, acc_sequences}
  end

  defp do_chunk_by(
         %Owl.Tag{sequences: sequences, data: data},
         chunk_acc,
         chunk_fun,
         acc,
         acc_sequences
       ) do
    {resolution, before_pattern, after_pattern, chunk_acc, next_acc_sequences} =
      do_chunk_by(data, chunk_acc, chunk_fun, [], acc_sequences ++ sequences)

    before_pattern = reverse_and_tag(sequences, before_pattern)

    next_acc_sequences =
      case after_pattern do
        [] -> next_acc_sequences -- sequences
        [""] -> next_acc_sequences -- sequences
        _ -> next_acc_sequences
      end

    {resolution, [before_pattern | acc], after_pattern, chunk_acc, next_acc_sequences}
  end

  defp do_chunk_by(value, chunk_acc, chunk_fun, acc, acc_sequences) when is_binary(value) do
    {resolution, new_chunk_acc, head, rest} = chunk_fun.(value, chunk_acc)

    {
      resolution,
      put_nonempty_head(head, acc),
      rest,
      new_chunk_acc,
      acc_sequences
    }
  end

  defp do_chunk_by(value, chunk_acc, chunk_fun, acc, acc_sequences) when is_integer(value) do
    do_chunk_by(<<value::utf8>>, chunk_acc, chunk_fun, acc, acc_sequences)
  end

  defp put_nonempty_head([], tail), do: tail
  defp put_nonempty_head(head, tail), do: [head | tail]
end
