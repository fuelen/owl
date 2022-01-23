defmodule Owl.SpinnerTest do
  use ExUnit.Case, async: true
  import CaptureIOFrames

  @sleep 5
  @tick_period_ms 30

  test "start, update label, stop" do
    id = make_ref()

    frames =
      capture_io_frames(fn live_screen_pid, render ->
        Owl.Spinner.start(
          id: id,
          refresh_every: @tick_period_ms,
          live_screen_server: live_screen_pid
        )

        render.()
        Process.sleep(@tick_period_ms + @sleep)
        render.()
        Owl.Spinner.update_label(id: id, label: "Label 1")
        Process.sleep(@tick_period_ms + @sleep)
        render.()
        Owl.Spinner.update_label(id: id, label: "Label 2")
        Process.sleep(@tick_period_ms + @sleep)
        render.()
        Owl.Spinner.stop(id: id, resolution: :ok)
      end)

    assert frames == [
             "\e[2K⠋\n",
             "\e[1A\e[2K⠙\n",
             "\e[1A\e[2K⠹ Label 1\n",
             "\e[1A\e[2K⠸ Label 2\n",
             "\e[1A\e[2K\e[32m✔\e[39m\e[0m\n"
           ]
  end
end
