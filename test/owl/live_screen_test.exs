defmodule Owl.LiveScreenTest do
  use ExUnit.Case, async: true
  import CaptureIOFrames

  @terminal_width 20

  test "server" do
    framese =
      capture_io_frames(
        fn live_screen_pid, render ->
          Owl.LiveScreen.await_render(live_screen_pid)
          IO.puts(live_screen_pid, "first\nput")
          render.()
          block1 = make_ref()
          Owl.LiveScreen.add_block(live_screen_pid, block1, state: "First block:\nupdate #1")
          render.()
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

    assert framese == [
             "first\nput\n\n",
             "\e[2KFirst block:\n\e[2Kupdate #1\n",
             "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Ksecond\nput\n\n\e[2KFirst block:\n\e[2Kupdate #1\n",
             "\e[2KSecond block:\n\e[2Kupdate #1\n\e[2K\n\e[2K\n",
             "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Kthird\nput\n\n\e[2KFirst block:\n\e[2Kupdate #1\n\e[2KSecond block:\n\e[2Kupdate #1\n\e[2K\n\e[2K\n",
             "\e[6A\e[2B\e[2KSecond block\n\e[2Kupdate #2\n\e[2K\n\e[2K\n",
             "new line\n\n\e[1A\e[2Knew line\n\n"
           ]
  end
end
