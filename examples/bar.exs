Owl.ProgressBar.start(id: :users, label: "Creating users", total: 100)

Enum.each(1..100, fn _ ->
  Process.sleep(10)
  Owl.ProgressBar.inc(id: :users)
end)

Owl.LiveScreen.await_render()
