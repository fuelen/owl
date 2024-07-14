defmodule Owl.Lines do
  @moduledoc false
  def format(lines, max_width, word_wrap, truncate_lines) do
    case max_width do
      :infinity ->
        lines

      0 ->
        Enum.map(lines, fn _line -> [] end)

      max_width ->
        if truncate_lines do
          Enum.map(lines, fn line -> Owl.Data.truncate(line, max_width) end)
        else
          Enum.flat_map(lines, fn
            [] -> [[]]
            line -> wrap_words(line, word_wrap, max_width)
          end)
        end
    end
  end

  defp wrap_words(line, :normal, max_width) do
    line
    |> Owl.Data.split(" ")
    |> Enum.flat_map_reduce(0, fn word, line_length ->
      word_length = Owl.Data.length(word)
      break_word? = word_length > max_width

      cond do
        break_word? ->
          {line_length, pre} =
            cond do
              line_length == 0 -> {0, nil}
              line_length == max_width -> {0, :break}
              line_length + 1 == max_width -> {0, :break}
              true -> {line_length, {:data, " "}}
            end

          first_part_length = max_width - if line_length == 0, do: 0, else: line_length + 1
          first_part = Owl.Data.slice(word, 0, first_part_length)

          rest_parts =
            Owl.Data.chunk_every(
              Owl.Data.slice(word, first_part_length, word_length - first_part_length),
              max_width
            )

          items =
            Enum.map_intersperse([first_part | rest_parts], :break, fn data -> {:data, data} end)

          line_length = List.last(rest_parts) |> Owl.Data.length()

          if pre do
            {[pre | items], line_length}
          else
            {items, line_length}
          end

        word_length + 1 == max_width or word_length == max_width ->
          if line_length == 0 do
            {[{:data, word}, :break], 0}
          else
            {[:break, {:data, word}, :break], 0}
          end

        word_length + line_length + 1 > max_width ->
          {[:break, {:data, word}], word_length}

        true ->
          if line_length == 0 do
            {[{:data, word}], word_length}
          else
            {[{:data, " "}, {:data, word}], word_length + line_length + 1}
          end
      end
    end)
    |> elem(0)
    |> Enum.chunk_by(fn item -> item == :break end)
    |> Enum.flat_map(fn
      [:break] -> []
      words -> [Enum.map(words, fn {:data, word} -> word end)]
    end)
  end

  defp wrap_words(line, :break_word, max_width) do
    Owl.Data.chunk_every(line, max_width)
  end
end
