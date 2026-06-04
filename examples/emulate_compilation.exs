require Logger

:ok = :logger.remove_handler(:default)

:ok =
  :logger.add_handler(:default, :logger_std_h, %{
    config: %{type: {:device, Owl.LiveScreen}},
    formatter: Logger.Formatter.new(),
    # On OTP 28+ `:logger.add_handler/3` injects `filter_default: :stop` plus the
    # kernel's default domain filters whenever the handler id is `:default` and no
    # `:filters` key is given. Those filters drop Elixir's `domain: [:elixir]` events,
    # so logs would silently never reach the device. Setting filters explicitly keeps
    # behaviour identical on OTP 27 and OTP 28+.
    filter_default: :log,
    filters: []
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
