defmodule Owl.SpinnerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @unreachable_refresh_interval 9999
  @terminal_width 50
  @sleep 10
  @render_separator "#@₴?$0"
  @tick_period_ms 100

  test "start, update label, stop" do
    id = make_ref()

    frames =
      capture_io(fn ->
        {:ok, live_screen_pid} =
          start_supervised(
            {Owl.LiveScreen,
             terminal_width: @terminal_width, refresh_every: @unreachable_refresh_interval}
          )

        {:ok, _pid} =
          start_supervised(
            {Owl.Spinner,
             id: id, refresh_every: @tick_period_ms, live_screen_server: live_screen_pid}
          )

        render = fn ->
          GenServer.call(live_screen_pid, :render)
          IO.write(@render_separator)
        end

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
        Owl.LiveScreen.stop(live_screen_pid)
      end)
      |> String.split(@render_separator)

    assert frames == [
             "\e[2K⠋\n",
             "\e[1A\e[2K⠙\n",
             "\e[1A\e[2K⠹ Label 1\n",
             "\e[1A\e[2K⠸ Label 2\n",
             "\e[1A\e[2K\e[32m✔\e[39m\e[0m\n"
           ]
  end
end
