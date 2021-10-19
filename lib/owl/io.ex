defmodule Owl.IO do
  def inspect(data) do
    ["\n", data, "\n"]
    |> Owl.Data.to_iodata()
    |> Owl.puts()

    data
  end
end
