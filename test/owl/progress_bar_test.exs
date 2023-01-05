defmodule Owl.ProgressBarTest do
  use ExUnit.Case, async: true
  import VirtualLiveScreen
  doctest Owl.ProgressBar

  @terminal_width 50
  @sleep 10

  test "render" do
    assert Owl.ProgressBar.render(%{
             label: "Demo",
             total: 200,
             current: 60,
             bar_width_ratio: 0.98,
             start_symbol: "[",
             end_symbol: "]",
             filled_symbol: "#",
             partial_symbols: [],
             empty_symbol: ".",
             screen_width: 40
           })
           |> to_string() == "…[#########.......................]  30%"
  end

  test "without timer" do
    id = make_ref()

    capture_frames(
      fn live_screen_pid, render ->
        {:ok, bar_pid} =
          Owl.ProgressBar.start(
            id: id,
            label: "users",
            total: 10,
            live_screen_server: live_screen_pid,
            screen_width: @terminal_width
          )

        render.()

        assert_received {:live_screen_frame,
                         "\e[2Kusers        [                              ]   0%\n"}

        Owl.ProgressBar.inc(id: id)
        Process.sleep(@sleep)
        render.()

        assert_received {:live_screen_frame,
                         "\e[1A\e[2Kusers        [≡≡≡                           ]  10%\n"}

        Owl.ProgressBar.inc(id: id)
        Owl.ProgressBar.inc(id: id)
        Owl.ProgressBar.inc(id: id, step: 7)
        Process.sleep(@sleep)

        refute Process.alive?(bar_pid)

        render.()

        assert_received {:live_screen_frame,
                         "\e[1A\e[2Kusers        [≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡] 100%\n"}
      end,
      terminal_width: @terminal_width
    )

    refute_received {:live_screen_frame, _}
  end

  @tick_period_ms 100
  @disable_autorender 999_999
  test "with timer" do
    id = make_ref()

    capture_frames(
      fn live_screen_pid, render ->
        {:ok, bar_pid} =
          Owl.ProgressBar.start(
            refresh_every: @tick_period_ms,
            id: id,
            label: "users",
            total: 10,
            timer: true,
            bar_width_ratio: 0.3,
            live_screen_server: live_screen_pid,
            screen_width: @terminal_width
          )

        Process.sleep(@tick_period_ms + @sleep)
        render.()

        assert_received {:live_screen_frame,
                         "\e[2Kusers                  00:00.1 [            ]   0%\n"}

        Owl.ProgressBar.inc(id: id, step: 10)
        Process.sleep(@tick_period_ms + @sleep)

        refute Process.alive?(bar_pid)

        render.()

        assert_received {:live_screen_frame,
                         "\e[1A\e[2Kusers                  00:00.2 [≡≡≡≡≡≡≡≡≡≡≡≡] 100%\n"}
      end,
      refresh_every: @disable_autorender
    )

    refute_received {:live_screen_frame, _}
  end
end
