long_running_tasks =
  [9000, 8000, 4000, 6000, 1000, 12000, 1300, 6000, 3000, 7900]
  |> Enum.with_index(1)
  |> Enum.map(fn {delay, index} ->
    {fn -> Process.sleep(delay) end,
     labels: [
       processing: "##{index} - processing",
       ok: "##{index} - completed",
       error: "##{index} - error"
     ]}
  end)

long_running_tasks
|> Task.async_stream(
  fn {long_running_task, opts} ->
    Owl.Spinner.run(long_running_task, opts)
  end,
  timeout: :infinity
)
|> Stream.run()
