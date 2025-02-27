defmodule Owl.LiveScreenTest do
  use ExUnit.Case, async: true
  import VirtualLiveScreen

  @terminal_width 20

  test "server" do
    capture_frames(
      fn live_screen_pid, _render ->
        # await_render() is almost identical to render.(), but executes a bit longer in time
        # In this test render function from callback is not used in order to test await_render.

        # await_render doesn't hang when timer is not enabled
        Owl.LiveScreen.await_render(live_screen_pid)
        refute_received {:live_screen_frame, _}

        IO.puts(live_screen_pid, "first\nput")

        assert_received {:live_screen_frame, "first\nput\n\n"}

        assert is_nil(:sys.get_state(live_screen_pid).timer_ref),
               "when buffer is empty and blocks are not set, then the timer must be canceled"

        block1 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block1, state: "First block:\nupdate #1")
        Owl.LiveScreen.await_render(live_screen_pid)
        assert_received {:live_screen_frame, "\e[2KFirst block:\n\e[2Kupdate #1\n"}

        refute is_nil(:sys.get_state(live_screen_pid).timer_ref),
               "when blocks are set, then the timer must be recreated after each render by timer"

        IO.puts(live_screen_pid, "second\nput")

        assert_received {:live_screen_frame,
                         "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Ksecond\nput\n\n\e[2KFirst block:\n\e[2Kupdate #1\n"}

        block2 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block2, state: "Second block:\nupdate #1\n")

        Owl.LiveScreen.await_render(live_screen_pid)
        assert_received {:live_screen_frame, "\e[2KSecond block:\n\e[2Kupdate #1\n\e[2K\n"}

        Owl.LiveScreen.update(live_screen_pid, block2, "Second block:\nupdate #2\n\n")
        Owl.LiveScreen.await_render(live_screen_pid)

        assert_received {:live_screen_frame,
                         "\e[3A\e[2KSecond block:\n\e[2Kupdate #2\n\e[2K\n\e[2K\n"}

        IO.puts(live_screen_pid, "third\nput")

        assert_received {:live_screen_frame,
                         "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Kthird\nput\n\n\e[2KFirst block:\n\e[2Kupdate #1\n\e[2KSecond block:\n\e[2Kupdate #2\n\e[2K\n\e[2K\n"}

        Owl.LiveScreen.update(live_screen_pid, block2, "Second block:\nupdate #3\n\n")
        Owl.LiveScreen.await_render(live_screen_pid)

        assert_received {:live_screen_frame,
                         "\e[4A\e[2KSecond block:\n\e[2Kupdate #3\n\e[2K\n\e[2K\n"}

        block3 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block3, state: "Third block:\nupdate #1")
        Owl.LiveScreen.await_render(live_screen_pid)
        assert_received {:live_screen_frame, "\e[2KThird block:\n\e[2Kupdate #1\n"}

        Owl.LiveScreen.update(live_screen_pid, block1, "First block:\nupdate #2")
        Owl.LiveScreen.update(live_screen_pid, block3, "Third block:\nupdate #2")

        Owl.LiveScreen.await_render(live_screen_pid)

        assert_received {:live_screen_frame,
                         "\e[8A\e[2KFirst block:\n\e[2Kupdate #2\n\e[4B\e[2KThird block:\n\e[2Kupdate #2\n"}

        Owl.LiveScreen.update(live_screen_pid, block2, "Second block\nupdate #4")
        Owl.LiveScreen.flush(live_screen_pid)

        assert_received {:live_screen_frame,
                         "\e[6A\e[2KSecond block\n\e[2Kupdate #4\n\e[2K\n\e[2K\e[2B\n"}

        IO.puts(live_screen_pid, "new line")
        assert_received {:live_screen_frame, "new line\n\n"}
        IO.puts(live_screen_pid, "new line")
        assert_received {:live_screen_frame, "\e[1A\e[2Knew line\n\n"}
        refute_received {:live_screen_frame, _}
      end,
      terminal_width: @terminal_width
    )
  end

  test "height of all blocks > height of the terminal" do
    capture_frames(
      fn live_screen_pid, render ->
        block1 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block1, state: "First block:\nupdate #1")

        block2 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block2, state: "Second block:\nupdate #1")

        block3 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block3, state: "Third block:\nupdate #1")
        render.()

        assert_received {:live_screen_frame,
                         "\e[2KSecond block:\n\e[2Kupdate #1\n\e[2KThird block:\n\e[2Kupdate #1\n"}

        Owl.LiveScreen.update(live_screen_pid, block1, "First block:\nupdate #1\nnew_line")
        render.()

        refute_received {:live_screen_frame, _}
        Owl.LiveScreen.update(live_screen_pid, block2, "Second block:\nupdate #2\nnew_line")
        render.()
        assert_received {:live_screen_frame, "\e[4A\e[2Kupdate #2\n\e[2Knew_line\e[2B\n"}

        Owl.LiveScreen.update(live_screen_pid, block2, "Second block:\nupdate #3\nnew_line")
        Owl.LiveScreen.update(live_screen_pid, block3, "Third block:\nupdate #2\nnew_line")
        render.()

        assert_received {:live_screen_frame,
                         "\e[3A\e[2Knew_line\n\e[2KThird block:\n\e[2Kupdate #2\n\e[2Knew_line\n"}

        Owl.LiveScreen.update(live_screen_pid, block3, "1\n2\n3\n4\n5")
        render.()
        assert_received {:live_screen_frame, "\e[3A\e[2K2\n\e[2K3\n\e[2K4\n\e[2K5\n"}

        IO.puts(live_screen_pid, "regular_output 1\nregular output 2")

        render.()

        assert_received {:live_screen_frame,
                         "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K\e[1A\e[2Kregular_output 1\nregular output 2\n\n\e[2K2\n\e[2K3\n\e[2K4\n\e[2K5\n"}

        refute_received {:live_screen_frame, _}
      end,
      terminal_width: @terminal_width,
      terminal_height: 5
    )
  end

  test "height of a single block > height of the terminal" do
    capture_frames(
      fn live_screen_pid, render ->
        block1 = make_ref()
        Owl.LiveScreen.add_block(live_screen_pid, block1, state: "1\n2\n3\n4\n5")

        render.()

        assert_received {:live_screen_frame, "\e[2K2\n\e[2K3\n\e[2K4\n\e[2K5\n"}

        Owl.LiveScreen.update(live_screen_pid, block1, "1")
        render.()

        assert_received {:live_screen_frame, "\e[4A\e[2K\n\e[2K\n\e[2K\n\e[2K\n"}

        refute_received {:live_screen_frame, _}
      end,
      terminal_width: @terminal_width,
      terminal_height: 5
    )
  end

  test "capture_stdio" do
    capture_frames(
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
        assert_receive {:live_screen_frame, "\e[2KProgress   [  ]   0%\n"}

        Owl.LiveScreen.capture_stdio(live_screen_pid, fn ->
          assert IO.puts("hello") == :ok
          assert IO.gets([]) == {:error, :enotsup}
          assert IO.getn([], 3) == {:error, :enotsup}
          assert :io.get_password() == {:error, :enotsup}
          assert :io.columns() == {:ok, @terminal_width}
          assert :io.rows() == {:ok, 5}
        end)

        assert_receive {:live_screen_frame, "\e[1A\e[2Khello\n\n\e[2KProgress   [  ]   0%\n"}
        # refute_receive {:live_screen_frame, _}

        Owl.ProgressBar.inc(id: :users)

        # sleep is needed in order to give time data to be delivered from ProgressBar to LiveScreen server
        Process.sleep(5)
        render.()
        assert_receive {:live_screen_frame, "\e[1A\e[2KProgress   [- ]  20%\n"}
        refute_receive {:live_screen_frame, _}
      end,
      terminal_width: @terminal_width,
      terminal_height: 5
    )
  end

  test "set_device and get_device" do
    terminal_width = 50
    terminal_height = 20

    device1 =
      ExUnit.Callbacks.start_supervised!(
        {VirtualLiveScreen.Device, pid: self(), columns: terminal_width, rows: terminal_height},
        id: :device1
      )

    device2 =
      ExUnit.Callbacks.start_supervised!(
        {VirtualLiveScreen.Device, pid: self(), columns: terminal_width, rows: terminal_height},
        id: :device2
      )

    live_screen_pid =
      ExUnit.Callbacks.start_supervised!(
        {Owl.LiveScreen, device: device1, terminal_width: terminal_width}
      )

    assert Owl.LiveScreen.get_device(live_screen_pid) == device1
    assert Owl.LiveScreen.set_device(live_screen_pid, device2) == :ok
    assert Owl.LiveScreen.get_device(live_screen_pid) == device2
  end
end
