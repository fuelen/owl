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
    |> Enum.intersperse(" ")
    |> Enum.flat_map_reduce({0, false}, fn
      %Owl.Tag{data: []}, acc ->
        {[], acc}

      [], acc ->
        {[], acc}

      word, {line_length, after_space?} ->
        word_length = Owl.Data.length(word)
        break_word? = word_length > max_width

        cond do
          break_word? ->
            {line_length, pre} =
              cond do
                line_length == 0 -> {0, nil}
                line_length == max_width -> {0, :break}
                true -> {line_length, nil}
              end

            first_part_length = max_width - line_length
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
              {[pre | items], {line_length, false}}
            else
              {items, {line_length, false}}
            end

          word_length == max_width ->
            if line_length == 0 do
              {[{:data, word}, :break], {0, false}}
            else
              {[:break, {:data, word}, :break], {0, false}}
            end

          word_length + line_length > max_width ->
            space? = word == " "

            if space? do
              {[:break], {0, true}}
            else
              {[:break, {:data, word}], {word_length, false}}
            end

          true ->
            space? = word == " "

            cond do
              space? and line_length == 0 and not after_space? ->
                {[], {0, true}}

              space? and after_space? ->
                {[data: "  "], {line_length + 2, false}}

              space? and word_length + line_length == max_width ->
                {[:break], {0, false}}

              true ->
                {[{:data, word}], {word_length + line_length, false}}
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
