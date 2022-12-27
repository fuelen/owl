data =
  for row_index <- 1..7 do
    for header_index <- 1..7, into: Map.new() do
      {"h#{header_index}", "r#{header_index}#{row_index}"}
    end
  end

Owl.LiveScreen.add_block(:table,
  render: fn
    nil -> ""
    max_width -> Owl.Table.new(data, max_width: max_width, truncate_lines: true, padding_x: 1)
  end
)

min_width = 2
max_width = 43

Stream.iterate(
  {:inc, min_width},
  fn {operation, width} ->
    Owl.LiveScreen.update(:table, width)
    Process.sleep(70)

    case {operation, width} do
      {:inc, ^max_width} -> {:dec, max_width - 1}
      {:inc, width} -> {:inc, width + 1}
      {:dec, ^min_width} -> {:inc, min_width + 1}
      {:dec, width} -> {:dec, width - 1}
    end
  end
)
|> Stream.run()
