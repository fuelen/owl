owl =
  """
     ,_,
    {o,o}
    /)  )
  ---"-"--
  """
  |> String.trim_trailing()

colors = [:blue, :red, :cyan, :yellow, :green, :black]

1..6
|> Enum.map(fn index ->
  owl
  |> Owl.Data.tag(Enum.random(colors))
  |> Owl.Box.new(title: to_string(index))
  |> Owl.Data.tag(Enum.random(colors))
end)
|> Enum.reverse()
|> Enum.reduce(&Owl.Data.zip/2)
|> Owl.Box.new(title: "6 owls")
|> Owl.Data.tag(:magenta)
|> Owl.IO.puts()
