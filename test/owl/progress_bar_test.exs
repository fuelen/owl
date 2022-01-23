defmodule Owl.ProgressBarTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  doctest Owl.ProgressBar

  @unreachable_refresh_interval 9999
  @terminal_width 50
  @sleep 10
  @render_separator "#@₴?$0"

  test "without timer" do
    id = make_ref()

    frames =
      capture_io(fn ->
        {:ok, live_screen_pid} =
          start_supervised(
            {Owl.LiveScreen,
             terminal_width: @terminal_width, refresh_every: @unreachable_refresh_interval}
          )

        assert is_pid(live_screen_pid)

        {:ok, bar_pid} =
          Owl.ProgressBar.start(
            id: id,
            label: "users",
            total: 10,
            live_screen_server: live_screen_pid,
            screen_width: @terminal_width
          )

        render = fn ->
          GenServer.call(live_screen_pid, :render)
          IO.write(@render_separator)
        end

        render.()
        Owl.ProgressBar.inc(id: id)
        Process.sleep(@sleep)
        render.()
        Owl.ProgressBar.inc(id: id)
        Owl.ProgressBar.inc(id: id)
        Owl.ProgressBar.inc(id: id, step: 7)
        Process.sleep(@sleep)
        Owl.LiveScreen.stop(live_screen_pid)

        refute Process.alive?(bar_pid)
      end)
      |> String.split(@render_separator)

    assert frames == [
             "\e[2Kusers   [                                   ]   0%\n",
             "\e[1A\e[2Kusers   [≡≡≡-                               ]  10%\n",
             "\e[1A\e[2Kusers   [≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡] 100%\n"
           ]
  end

  @tick_period_ms 100
  test "with timer" do
    id = make_ref()

    frames =
      capture_io(fn ->
        {:ok, live_screen_pid} =
          start_supervised(
            {Owl.LiveScreen,
             terminal_width: @terminal_width, refresh_every: @unreachable_refresh_interval}
          )

        {:ok, bar_pid} =
          Owl.ProgressBar.start(
            id: id,
            label: "users",
            total: 10,
            timer: true,
            bar_width_ratio: 0.3,
            live_screen_server: live_screen_pid,
            screen_width: @terminal_width
          )

        render = fn ->
          GenServer.call(live_screen_pid, :render)
          IO.write(@render_separator)
        end

        Process.sleep(@tick_period_ms + @sleep)
        render.()
        Owl.ProgressBar.inc(id: id, step: 10)
        Process.sleep(@tick_period_ms + @sleep)

        Owl.LiveScreen.stop(live_screen_pid)
        refute Process.alive?(bar_pid)
      end)
      |> String.split(@render_separator)

    assert frames == [
             "\e[2Kusers               00:00.1 [               ]   0%\n",
             "\e[1A\e[2Kusers               00:00.2 [≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡] 100%\n"
           ]
  end
end
