defmodule Owl.LiveScreenTest do
  use ExUnit.Case, async: true
  import CaptureIOFrames

  @terminal_width 20

  test "server" do
    frames =
      capture_io_frames(
        fn live_screen_pid, _render ->
          # await_render() + render_separator() is almost indentical to render.(), but a bit longer in time.
          # In this test we override render function in order to test await_render.
          render = fn ->
            Owl.LiveScreen.await_render(live_screen_pid)
            render_separator()
          end

          # await_render doesn't hang when timer is not enabled
          Owl.LiveScreen.await_render(live_screen_pid)

          IO.puts(live_screen_pid, "first\nput")

          render.()

          assert is_nil(:sys.get_state(live_screen_pid).timer_ref),
                 "when buffer is empty and blocks are not set, then the timer must be canceled"

          block1 = make_ref()
          Owl.LiveScreen.add_block(live_screen_pid, block1, state: "First block:\nupdate #1")
          render.()

          refute is_nil(:sys.get_state(live_screen_pid).timer_ref),
                 "when blocks are set, then the timer must be recreated after each render by timer"

          IO.puts(live_screen_pid, "second\nput")
          render.()
          block2 = make_ref()

          Owl.LiveScreen.add_block(live_screen_pid, block2, state: "Second block:\nupdate #1\n\n")

          render.()
          IO.puts(live_screen_pid, "third\nput")
          render.()
          Owl.LiveScreen.update(live_screen_pid, block2, "Second block\nupdate #2")
          Owl.LiveScreen.flush(live_screen_pid)
          render.()
          IO.puts(live_screen_pid, "new line")
          IO.puts(live_screen_pid, "new line")
        end,
        terminal_width: @terminal_width
      )

    assert frames == [
             "first\nput\n\n",
             "\e[2KFirst block:\n\e[2Kupdate #1\n",
             "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Ksecond\nput\n\n\e[2KFirst block:\n\e[2Kupdate #1\n",
             "\e[2KSecond block:\n\e[2Kupdate #1\n\e[2K\n\e[2K\n",
             "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Kthird\nput\n\n\e[2KFirst block:\n\e[2Kupdate #1\n\e[2KSecond block:\n\e[2Kupdate #1\n\e[2K\n\e[2K\n",
             "\e[6A\e[2B\e[2KSecond block\n\e[2Kupdate #2\n\e[2K\n\e[2K\n",
             "new line\n\n\e[1A\e[2Knew line\n\n"
           ]
  end

  test "capture_stdio" do
    frames =
      capture_io_frames(
        fn live_screen_pid, render ->
          Owl.ProgressBar.start(
            id: :users,
            label: "Progress",
            total: 5,
            screen_width: @terminal_width,
            bar_width_ratio: 0.2,
            live_screen_server: live_screen_pid
          )

          render.()

          Owl.ProgressBar.inc(id: :users)

          # we can't use render.() inside capture_stdio, as render.() writes separators to stdio,
          # which are sent to LiveScreen and we have not desired output
          Owl.LiveScreen.capture_stdio(live_screen_pid, fn ->
            IO.puts("hello")
          end)

          # sleep is needed in order to give time data to be delivered to LiveScreen server
          Process.sleep(5)
          render.()
          Owl.ProgressBar.inc(id: :users)
          # sleep is needed in order to give time data to be delivered to LiveScreen server
          Process.sleep(5)
          render.()
        end,
        terminal_width: @terminal_width
      )

    assert frames == [
             "\e[2KProgress [    ]   0%\n",
             "\e[1A\e[2Khello\n\n\e[2KProgress [=   ]  20%\n",
             "\e[1A\e[2KProgress [≡=  ]  40%\n"
           ]
  end
end
