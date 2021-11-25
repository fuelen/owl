defmodule Owl.LiveScreenTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @unreachable_refresh_interval 9999
  @terminal_width 20
  @sleep 10
  @render_separator "#@₴?$0"

  test "server" do
    renders =
      capture_io(fn ->
        {:ok, live_screen_pid} =
          start_supervised(
            {Owl.LiveScreen,
             terminal_width: @terminal_width, refresh_every: @unreachable_refresh_interval}
          )

        render = fn ->
          send(live_screen_pid, :render)
          Process.sleep(@sleep)
          IO.write(@render_separator)
        end

        Owl.LiveScreen.put(live_screen_pid, "first\nput")
        render.()
        block1 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block1, state: "First block:\nupdate #1")
        render.()
        Owl.LiveScreen.put(live_screen_pid, "second\nput")
        render.()
        block2 = make_ref()

        Owl.LiveScreen.add_block(live_screen_pid, block2, state: "Second block:\nupdate #1")

        render.()
        Owl.LiveScreen.put(live_screen_pid, "third\nput")
        render.()
        Owl.LiveScreen.update(live_screen_pid, block2, "Second block\nupdate #2")
        Process.sleep(@sleep)
        Owl.LiveScreen.stop(live_screen_pid)
      end)

    assert String.split(renders, @render_separator) == [
             "first               \nput                 \n",
             "First block:\nupdate #1\n",
             "\e[2Asecond              \nput                 \nFirst block:        \nupdate #1           \n",
             "Second block:\nupdate #1\n",
             "\e[4Athird               \nput                 \nFirst block:        \nupdate #1           \nSecond block:       \nupdate #1           \n",
             "\e[4A\e[2BSecond block        \nupdate #2           \n"
           ]
  end
end
