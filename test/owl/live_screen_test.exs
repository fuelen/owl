defmodule Owl.LiveScreenTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @terminal_width 20
  @sleep 10
  @render_separator "#@₴?$0"

  test "server" do
    renders =
      capture_io(fn ->
        {:ok, live_screen_pid} =
          start_supervised({Owl.LiveScreen, terminal_width: @terminal_width, refresh_every: 10})

        render = fn ->
          GenServer.call(live_screen_pid, :render)
          IO.write(@render_separator)
        end

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
        Process.sleep(@sleep)
        IO.write(@render_separator)
        IO.puts(live_screen_pid, "new line")
        IO.puts(live_screen_pid, "new line")
        Owl.LiveScreen.stop(live_screen_pid)
      end)

    assert String.split(renders, @render_separator) == [
             "first\nput\n\n",
             "First block:\nupdate #1\n",
             "\e[3Asecond              \nput                 \n                    \nFirst block:        \nupdate #1           \n",
             "Second block:\nupdate #1\n\n\n",
             "\e[7Athird               \nput                 \n                    \nFirst block:        \nupdate #1           \nSecond block:       \nupdate #1           \n                    \n                    \n",
             "\e[6A\e[2BSecond block        \nupdate #2           \n                    \n                    \n",
             "new line\n\n\e[1Anew line            \n                    \n"
           ]
  end

  test "fill_with_spaces" do
    assert "qwe\e[22m\n14:34:08.584 [info]  qqwewwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww\n\e[0m"
           |> Owl.LiveScreen.fill_with_spaces(11) == [
             ["qwe", "\e[22m", [" ", " ", " ", " ", " ", " ", " ", " "]],
             "\n",
             [
               "14:34:08.58",
               "4 [info]  q",
               "qwewwwwwwww",
               "wwwwwwwwwww",
               "wwwwwwwwwww",
               "wwwwwwwwwww",
               "wwwwwwwwwww",
               "wwwwwwwwwww",
               "ww",
               [" ", " ", " ", " ", " ", " ", " ", " ", " "]
             ],
             "\n",
             ["\e[0m", [" ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " "]]
           ]

    assert "\e[33mDemo Progress #1: \e[39m\e[49mtest 2test 2test 2test 2test 2test 2test 2test 2test 2test 2\e[0m\n"
           |> Owl.LiveScreen.fill_with_spaces(100) == [
             [
               "\e[33m",
               "Demo Progress #1: ",
               "\e[39m\e[49m",
               "test 2test 2test 2test 2test 2test 2test 2test 2test 2test 2",
               "\e[0m",
               [
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " ",
                 " "
               ]
             ],
             "\n",
             [
               List.duplicate(" ", 100)
             ]
           ]
  end
end
