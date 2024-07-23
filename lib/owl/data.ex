defmodule Owl.Data do
  @moduledoc """
  A set of functions for `t:chardata/0` with [tags](`Owl.Tag`).
  """

  alias Owl.Data.Sequence

  @typedoc """
  A recursive data type that is similar to `t:chardata/0`, but additionally supports `t:Owl.Tag.t/1`.

  Can be printed using `Owl.IO.puts/2`.
  """
  # improper lists are not here, just because they were not tested
  @type t :: [binary() | non_neg_integer() | t() | Owl.Tag.t(t())] | Owl.Tag.t(t()) | binary()

  @typedoc ~S"""
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

      iex> Owl.Data.tag(["hello ", Owl.Data.tag("world", :green), "!!!"], :red)
      Owl.Data.tag(["hello ", Owl.Data.tag("world", :green), "!!!"], :red)

      iex> Owl.Data.tag("hello world", [:green, :red_background])
      Owl.Data.tag("hello world", [:green, :red_background])
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
      ~c"Hello"

      iex> Owl.Data.tag(["Hello", Owl.Data.tag("world", :green)], :red) |> Owl.Data.untag()
      ["Hello", "world"]

      iex> ["Hello ", Owl.Data.tag("world", :red), ["!"]] |> Owl.Data.untag()
      ["Hello ", "world", ["!"]]
  """
  @spec untag(t()) :: IO.chardata()
  def untag(data) when is_list(data) do
    Enum.map(data, &untag_child/1)
  end

  def untag(%Owl.Tag{data: data}) do
    untag(data)
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

      # if ucwidth dependency is present, then it is used to calculate the length of the string
      iex> Owl.Data.length("😂")
      2
  """
  @spec length(t()) :: non_neg_integer()
  if Code.ensure_loaded?(Ucwidth) do
    def length(data) when is_binary(data) do
      Ucwidth.width(data)
    end
  else
    def length(data) when is_binary(data) do
      String.length(data)
    end
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
      ...> |> Owl.Data.to_chardata()
      Owl.Data.to_chardata(["first\\nsecond\\n", Owl.Data.tag("third\\nfourth", :red)])
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

  @doc ~S"""
  Transforms data to `t:chardata/0` format which can be consumed by `IO` module.

  ## Examples

      iex> "hello" |> Owl.Data.tag(:red) |> Owl.Data.to_chardata()
      [[[[[] | "\e[31m"], "hello"] | "\e[39m"] | "\e[0m"]
  """
  @spec to_chardata(t()) :: IO.chardata()
  def to_chardata(data) do
    # combination of lines + unlines is needed in order to break background and do not spread it to the end of the line
    data
    |> lines()
    |> unlines()
    |> do_to_ansidata(%{})
    |> IO.ANSI.format()
  end

  @doc false
  @deprecated "Use `Owl.Data.to_chardata/1` instead"
  def to_ansidata(data) do
    to_chardata(data)
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
            return_to = Sequence.default_value_by_type!(sequence_type)

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

  @doc ~S"""
  Transforms chardata, replacing raw escape sequences with tags (see `tag/2`).

  This makes it possible to use data formatted outside of Owl with other Owl modules, like `Owl.Box`.

  ## Examples

      iex> [:red, "hello"] |> IO.ANSI.format() |> Owl.Data.from_chardata()
      Owl.Data.tag("hello", :red)

      іex> {output, 0} = Owl.System.cmd("bat", ["README.md", "--color=always", "--style=plain"])
      ...> output
      ...> |> Owl.Data.from_chardata()
      ...> |> Owl.Box.new(title: Owl.Data.tag("README.md", :cyan), border_tag: :light_cyan)
      ...> |> Owl.IO.puts()
  """
  @spec from_chardata(IO.chardata()) :: t()
  def from_chardata(data) do
    data =
      Regex.split(~r/\e\[(\d+;)*\d+m/, IO.chardata_to_string(data),
        include_captures: true,
        trim: true
      )

    {data, _open_tags} = do_from_chardata(data, %{})
    data
  end

  @doc false
  @deprecated "Use `Owl.Data.from_chardata/1` instead"
  def from_ansidata(data) do
    from_chardata(data)
  end

  defp do_from_chardata(binary, open_tags) when is_binary(binary) do
    case Owl.Data.Sequence.split(binary) do
      {:ok, sequences} ->
        open_tags =
          Enum.reduce(sequences, open_tags, fn sequence, acc ->
            case Sequence.binary_to_name(sequence) do
              nil -> acc
              :reset -> %{}
              name -> update_open_tags(acc, Sequence.type!(name), name)
            end
          end)

        {[], open_tags}

      :error ->
        {tag_all(binary, open_tags), open_tags}
    end
  end

  defp do_from_chardata([], open_tags) do
    {[], open_tags}
  end

  defp do_from_chardata([inner], open_tags) do
    do_from_chardata(inner, open_tags)
  end

  defp do_from_chardata([head | tail], open_tags) do
    {head, open_tags} = do_from_chardata(head, open_tags)
    {tail, open_tags} = do_from_chardata(tail, open_tags)

    case {head, tail} do
      {[], _} ->
        {tail, open_tags}

      {_, []} ->
        {head, open_tags}

      {%Owl.Tag{data: p1, sequences: s}, %Owl.Tag{data: p2, sequences: s}} ->
        data =
          if is_list(p2) do
            [p1 | p2]
          else
            [p1, p2]
          end

        {tag(data, s), open_tags}

      {%Owl.Tag{data: p1, sequences: s}, [%Owl.Tag{data: p2, sequences: s} | rest]} ->
        data =
          if is_list(p2) do
            [p1 | p2]
          else
            [p1, p2]
          end

        {[tag(data, s) | rest], open_tags}

      {head, tail} when is_list(tail) ->
        {[head | tail], open_tags}

      {head, tail} ->
        {[head, tail], open_tags}
    end
  end

  defp tag_all(data, open_tags) do
    case Map.values(open_tags) do
      [] -> data
      tags -> tag(data, tags)
    end
  end

  defp update_open_tags(open_tags, type, name) do
    if name == Sequence.default_value_by_type!(type) do
      Map.delete(open_tags, type)
    else
      Map.put(open_tags, type, name)
    end
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
      nil,
      fn value, nil ->
        [head | tail] = String.split(value, pattern, parts: 2)

        head = if head == "", do: [], else: head
        resolution = if tail == [], do: :cont, else: :chunk

        {resolution, nil, head, tail}
      end
    )
  end

  @doc """
  Truncates data, so the length of returning data is <= `length`.

  Puts ellipsis symbol at the end if data was truncated.

  ## Examples
      iex> Owl.Data.truncate([Owl.Data.tag("Hello", :red), Owl.Data.tag(" world!", :green)], 10)
      [Owl.Data.tag(["Hello"], :red), Owl.Data.tag([" wor"], :green), "…"]

      iex> Owl.Data.truncate("Hello", 10)
      "Hello"

      iex> Owl.Data.truncate("Hello", 4)
      ["Hel", "…"]

      iex> Owl.Data.truncate("Hello", 5)
      "Hello"

      iex> Owl.Data.truncate("Hello", 1)
      "…"
  """
  @spec truncate(t(), pos_integer()) :: t()
  def truncate(data, length) when length > 0 do
    import Kernel, except: [length: 1]

    cond do
      length == 1 -> "…"
      length(data) > length -> data |> slice(0, length - 1) |> List.wrap() |> Enum.concat(["…"])
      true -> data
    end
  end

  @doc """
  Returns a data starting at the offset `start`, and of the given `length`.

  It is like `String.slice/3` but for `t:t/0`.

  ## Examples

      iex> Owl.Data.slice([Owl.Data.tag("Hello world", :red), Owl.Data.tag("!", :green)], 6, 7)
      [Owl.Data.tag(["world"], :red), Owl.Data.tag(["!"], :green)]

      iex> Owl.Data.slice(Owl.Data.tag("Hello world", :red), 20, 10)
      []
  """
  @spec slice(t(), integer(), pos_integer()) :: t()
  def slice(data, start, length) when is_integer(start) and is_integer(length) and length > 0 do
    result =
      chunk_by(data, {start, length}, fn value, {start, length} ->
        value_length = String.length(value)

        if value_length <= start do
          {:cont, {start - value_length, length}, [], []}
        else
          result = String.slice(value, start, length)

          case length - String.length(result) do
            0 -> {:halt, result}
            new_length -> {:cont, {0, new_length}, result, []}
          end
        end
      end)

    # cleanup output, so it just looks prettier
    result
    |> trim_leading_blank_tags()
    |> maybe_unwrap_list()
  end

  defp maybe_unwrap_list([item]), do: item
  defp maybe_unwrap_list(items), do: items

  defp trim_leading_blank_tags([%Owl.Tag{data: []} | tail]) do
    trim_leading_blank_tags(tail)
  end

  defp trim_leading_blank_tags(result), do: result

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
      0,
      fn value, cut_left ->
        split_at = if cut_left == 0, do: count, else: cut_left

        case String.split_at(value, split_at) do
          {head, ""} ->
            left = split_at - String.length(head)
            resolution = if left == 0, do: :chunk, else: :cont

            {resolution, left, head, []}

          {head, rest} ->
            {:chunk, 0, head, [rest]}
        end
      end
    )
  end

  defp chunk_by(data, chunk_acc, chunk_fun), do: chunk_by(data, chunk_acc, chunk_fun, [])
  defp chunk_by([], _chunk_acc, _chunk_fun, _acc_sequences), do: []

  defp chunk_by(data, chunk_acc, chunk_fun, acc_sequences) do
    case do_chunk_by(data, chunk_acc, chunk_fun, [], acc_sequences) do
      {:halt, head, next_acc_sequences} ->
        reverse_and_tag(acc_sequences ++ next_acc_sequences, head)

      {_, head, tail, chunk_acc, next_acc_sequences} ->
        [
          reverse_and_tag(acc_sequences ++ next_acc_sequences, head)
          | chunk_by(tail, chunk_acc, chunk_fun, next_acc_sequences)
        ]
    end
  end

  defp do_chunk_by([head | tail], chunk_acc, chunk_fun, acc, acc_sequences) do
    case do_chunk_by(head, chunk_acc, chunk_fun, acc, acc_sequences) do
      {:cont, new_head, new_tail, chunk_acc, new_acc_sequences} ->
        new_tail
        |> put_nonempty_head(tail)
        |> do_chunk_by(chunk_acc, chunk_fun, new_head, new_acc_sequences)

      {:halt, new_head, new_acc_sequences} ->
        new_acc_sequences =
          case new_head do
            [%Owl.Tag{sequences: sequences} | _] -> new_acc_sequences -- sequences
            _ -> new_acc_sequences
          end

        {:halt, new_head, new_acc_sequences}

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
    case do_chunk_by(data, chunk_acc, chunk_fun, [], acc_sequences ++ sequences) do
      {:halt, head, next_acc_sequences} ->
        head = reverse_and_tag(sequences, head)

        next_acc_sequences = next_acc_sequences -- sequences

        {:halt, [head | acc], next_acc_sequences}

      {resolution, head, tail, chunk_acc, next_acc_sequences} ->
        head = reverse_and_tag(sequences, head)

        next_acc_sequences =
          case tail do
            [] -> next_acc_sequences -- sequences
            [""] -> next_acc_sequences -- sequences
            _ -> next_acc_sequences
          end

        {resolution, [head | acc], tail, chunk_acc, next_acc_sequences}
    end
  end

  defp do_chunk_by(value, chunk_acc, chunk_fun, acc, acc_sequences) when is_binary(value) do
    case chunk_fun.(value, chunk_acc) do
      {:halt, head} ->
        {:halt, put_nonempty_head(head, acc), acc_sequences}

      {resolution, new_chunk_acc, head, rest} ->
        {
          resolution,
          put_nonempty_head(head, acc),
          rest,
          new_chunk_acc,
          acc_sequences
        }
    end
  end

  defp do_chunk_by(value, chunk_acc, chunk_fun, acc, acc_sequences) when is_integer(value) do
    do_chunk_by(<<value::utf8>>, chunk_acc, chunk_fun, acc, acc_sequences)
  end

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

  defp sequences_to_state(init, sequences) do
    Enum.reduce(sequences, init, fn sequence, acc ->
      Map.put(acc, Sequence.type!(sequence), sequence)
    end)
  end

  defp put_nonempty_head([], tail), do: tail
  defp put_nonempty_head(head, tail), do: [head | tail]
end
