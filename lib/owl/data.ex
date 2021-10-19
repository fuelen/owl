defmodule Owl.Data do
  def tag(data, sequences) do
    Owl.Data.Tag.new(data, sequences)
  end

  @box_symbols %{
    top_left: "┌",
    top: "─",
    top_right: "┐",
    right: "│",
    left: "│",
    bottom_left: "└",
    bottom: "─",
    bottom_right: "┘"
  }
  def box(data, opts \\ []) do
    padding_top = Keyword.get(opts, :padding_top, 0)
    padding_bottom = Keyword.get(opts, :padding_bottom, 0)
    padding_left = Keyword.get(opts, :padding_left, 2)
    padding_right = Keyword.get(opts, :padding_right, 2)
    min_length = Keyword.get(opts, :min_length, 0)
    align = Keyword.get(opts, :align, :left)

    lines =
      (List.duplicate([], padding_top) ++ split(data, "\n") ++ List.duplicate([], padding_bottom))
      |> Enum.map(&{&1, Owl.Data.length(&1)})

    max_line_length = Enum.max([min_length | Enum.map(lines, &elem(&1, 1))])

    [
      @box_symbols.top_left,
      String.duplicate(@box_symbols.top, max_line_length + padding_left + padding_right),
      @box_symbols.top_right,
      "\n",
      lines
      |> Enum.map(fn {line, length} ->
        {padding_before, padding_after} =
          case align do
            :left ->
              {padding_left, max_line_length - length + padding_right}

            :right ->
              {max_line_length - length + padding_left, padding_right}

            :center ->
              to_center = div(max_line_length - length, 2)
              {padding_left + to_center, max_line_length - length - to_center + padding_right}
          end

        [
          @box_symbols.left,
          String.duplicate(" ", padding_before),
          line,
          String.duplicate(" ", padding_after),
          @box_symbols.right
        ]
      end)
      |> Enum.intersperse("\n"),
      "\n",
      @box_symbols.bottom_left,
      String.duplicate(@box_symbols.bottom, max_line_length + padding_left + padding_right),
      @box_symbols.bottom_right
    ]
  end

  def length(data) when is_binary(data) do
    String.length(data)
  end

  def length(data) when is_list(data) do
    Enum.reduce(data, 0, fn item, acc -> Owl.Data.length(item) + acc end)
  end

  def length(%Owl.Data.Tag{data: data}) do
    Owl.Data.length(data)
  end

  def add_prefix(data, prefix) do
    data
    |> split("\n")
    |> Enum.map(fn line ->
      [prefix, line]
    end)
    |> Enum.intersperse("\n")
  end

  def to_iodata(data) do
    data
    |> split("\n")
    |> Enum.intersperse("\n")
    |> do_to_iodata(%{foreground: :default_color, background: :default_background})
    |> IO.ANSI.format()
  end

  defp do_to_iodata(
         %Owl.Data.Tag{sequences: sequences, data: data},
         %{foreground: fg, background: bg}
       ) do
    parent_sequences = Enum.reject([fg, bg], &is_nil/1)

    [
      sequences,
      do_to_iodata(data, sequences_to_state(parent_sequences ++ sequences)),
      parent_sequences
    ]
  end

  defp do_to_iodata([head | tail], state) do
    [do_to_iodata(head, state) | do_to_iodata(tail, state)]
  end

  defp do_to_iodata(term, _state), do: term

  defp maybe_wrap_to_tag([], [element]), do: element
  defp maybe_wrap_to_tag([], data), do: data

  defp maybe_wrap_to_tag(sequences1, [%Owl.Data.Tag{sequences: sequences2, data: data}]) do
    Owl.Data.Tag.new(data, collapse_sequences(sequences1 ++ sequences2))
  end

  defp maybe_wrap_to_tag(sequences, data) do
    Owl.Data.Tag.new(data, collapse_sequences(sequences))
  end

  defp reverse_and_tag(sequences, [%Owl.Data.Tag{sequences: last_sequences} | _] = data) do
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
            [%Owl.Data.Tag{sequences: sequences} | _] -> new_acc_sequences -- sequences
            _ -> new_acc_sequences
          end

        new_head =
          case new_head do
            [%Owl.Data.Tag{data: []} | rest] -> rest
            list -> list
          end

        {new_head, [new_tail | tail], new_acc_sequences}
    end
  end

  defp do_split([], _pattern, acc, acc_sequences) do
    {acc, [], acc_sequences}
  end

  defp do_split(
         %Owl.Data.Tag{sequences: sequences, data: data},
         pattern,
         acc,
         acc_sequences
       ) do
    {before_pattern, after_pattern, next_acc_sequences} =
      do_split(data, pattern, [], acc_sequences ++ sequences)

    before_pattern = reverse_and_tag(sequences, before_pattern)

    next_acc_sequences =
      case {before_pattern, after_pattern} do
        {%Owl.Data.Tag{sequences: sequences}, []} -> next_acc_sequences -- sequences
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
