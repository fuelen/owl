require Logger

:ok = :logger.remove_handler(:default)

:ok =
  :logger.add_handler(:default, :logger_std_h, %{
    config: %{type: {:device, Owl.LiveScreen}},
    formatter: Logger.Formatter.new()
  })

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
            Owl.Data.tag(dependency, :yellow),
            "\n",
            "compiling: ",
            Owl.Data.tag("done", :green),
            "\n"
          ]

        {:filename, filename} ->
          [
            "dependency: ",
            Owl.Data.tag(dependency, :yellow),
            "\n",
            "compiling: ",
            Owl.Data.tag(to_string(filename), :cyan),
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
