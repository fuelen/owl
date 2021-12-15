1..10
|> Enum.map(fn index ->
  Task.async(fn ->
    range = 1..Enum.random(100..300)

    label = "Demo Progress ##{index}"

    Owl.ProgressBar.start(
      id: {:demo, index},
      label: label,
      total: range.last,
      timer: true,
      bar_width_ratio: 0.3,
      filled_symbol: Owl.Tag.new("#", :red),
      empty_symbol: Owl.Tag.new("-", :light_black),
      partial_symbols: []
    )

    Enum.each(range, fn _ ->
      Process.sleep(Enum.random(10..50))
      Owl.ProgressBar.inc(id: {:demo, index})
    end)
  end)
end)
|> Task.await_many(:infinity)

Owl.LiveScreen.flush()
