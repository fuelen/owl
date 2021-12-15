require Logger
Logger.configure_backend(:console, device: Owl.LiveScreen)

["ecto", "phoenix", "ex_doc", "broadway"]
|> Enum.map(fn dependency ->
  Task.async(fn ->
    block_id = {:dependency, dependency}

    Owl.LiveScreen.add_block(block_id,
      state: :init,
      render: fn
        :init ->
          "init..."

        :compiled ->
          [
            "dependency: ",
            Owl.Tag.new(dependency, :yellow),
            "\n",
            "compiling: ",
            Owl.Tag.new("done", :green),
            "\n"
          ]

        {:filename, filename} ->
          [
            "dependency: ",
            Owl.Tag.new(dependency, :yellow),
            "\n",
            "compiling: ",
            Owl.Tag.new(to_string(filename), :cyan),
            "\n"
          ]
      end
    )

    1..10
    |> Enum.map(&"filename#{&1}.ex")
    |> Enum.each(fn filename ->
      Owl.LiveScreen.update(block_id, {:filename, filename})
      Process.sleep(Enum.random([100, 300, 500, 1000, 1500]))
      Logger.debug("#{filename} compiled for dependency #{dependency}")
    end)

    Owl.LiveScreen.update(block_id, :compiled)
  end)
end)
|> Task.await_many(:infinity)
