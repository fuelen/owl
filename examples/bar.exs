Owl.ProgressBar.start(id: :users, label: "Creating users", total: 100)

Enum.each(1..100, fn _ ->
  Process.sleep(10)
  Owl.ProgressBar.inc(id: :users)
end)

# Wait a bit to give ProgressBar server a time to send last state update to LiveScreen
Process.sleep(1)
Owl.LiveScreen.flush()
