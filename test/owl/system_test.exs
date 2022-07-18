defmodule Owl.SystemTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import VirtualLiveScreen

  describe inspect(&Owl.System.daemon_cmd/4) do
    test "successful run" do
      count_active_children = fn ->
        DynamicSupervisor.count_children(Owl.DaemonsSupervisor).active
      end

      children_number = count_active_children.()

      log =
        capture_log(fn ->
          assert Owl.System.daemon_cmd("sleep", ["5"], fn ->
                   Process.sleep(10)
                   assert count_active_children.() == children_number + 1

                   2 + 2
                 end) == 4
        end)

      assert log =~ "$ sleep 5"
      assert log =~ "Started daemon sleep with OS pid"
      assert log =~ "$ kill"
      assert count_active_children.() == children_number
    end

    test "successful run with :ready_check option" do
      sh_script = """
      sleep 1
      echo READY
      sleep 5
      echo "the script must be killed before printing this text"
      """

      daemon_script_path = Path.join(System.tmp_dir!(), "owl-#{:erlang.unique_integer()}")
      File.write!(daemon_script_path, sh_script)
      on_exit(fn -> File.rm!(daemon_script_path) end)

      capture_frames(fn live_screen_pid, _render ->
        log =
          capture_log(fn ->
            assert Owl.System.daemon_cmd(
                     "sh",
                     [daemon_script_path],
                     fn -> 2 + 2 end,
                     device: live_screen_pid,
                     ready_check: fn "READY\n" -> true end
                   ) == 4
          end)

        assert_received {:live_screen_frame, "\e[36msh: \e[39m READY\e[0m\n\n"}

        assert log =~ "$ sh #{daemon_script_path}"
        assert log =~ "Started daemon sh with OS pid"
        assert log =~ "$ kill"
      end)

      refute_received {:live_screen_frame, _}
    end

    test "premature exit of the daemon" do
      Process.flag(:trap_exit, true)

      capture_frames(fn live_screen_pid, _render ->
        child_pid =
          spawn_link(fn ->
            capture_log(fn ->
              Owl.System.daemon_cmd(
                "echo",
                ["sorry, port is busy"],
                fn -> Process.sleep(100_000) end,
                device: live_screen_pid
              )
            end)
          end)

        # sometimes echo command is not fast enough, so we have to increase default timeout,
        assert_receive {:EXIT, ^child_pid, {:premature_port_exit, 0}}, 500
        assert_received {:live_screen_frame, "\e[36mecho: \e[39m sorry, port is busy\e[0m\n\n"}
      end)

      refute_received {:live_screen_frame, _}
    end

    test "death of the caller" do
      Process.flag(:trap_exit, true)

      parent_pid = self()

      capture_frames(fn live_screen_pid, _render ->
        log =
          capture_log(fn ->
            child_pid =
              spawn_link(fn ->
                Owl.System.daemon_cmd(
                  "sleep",
                  ["5"],
                  fn ->
                    {:links, [^parent_pid, daemon_pid]} = Process.info(self(), :links)
                    send(parent_pid, {:daemon_pid, daemon_pid})

                    Process.sleep(100_000)
                  end,
                  device: live_screen_pid
                )
              end)

            # sleep in order to give time to send daemon_pid to parent_pid
            Process.sleep(50)
            Process.exit(child_pid, :kill)

            # sleep in order to give time to daemon to execute terminate callback and log kill message
            Process.sleep(50)

            assert_receive {:EXIT, ^child_pid, :killed}
          end)

        assert log =~ "$ sleep 5"
        assert log =~ "Started daemon sleep with OS pid"
        assert log =~ "$ kill"
      end)

      assert_received {:daemon_pid, daemon_pid}
      monitor_ref = Process.monitor(daemon_pid)
      assert_receive {:DOWN, ^monitor_ref, :process, ^daemon_pid, _}

      refute_received {:live_screen_frame, _}
    end
  end

  test inspect(&Owl.System.cmd/3) do
    assert capture_log(fn ->
             Owl.System.cmd("echo", [])
           end) =~ "$ echo\n"

    assert capture_log(fn ->
             Owl.System.cmd("echo", ["http://example.com"])
           end) =~ "$ echo http://example.com\n"

    assert capture_log(fn ->
             Owl.System.cmd("echo", ["http://example.com", secret: "password"])
           end) =~ "$ echo http://example.com ********\n"

    assert capture_log(fn ->
             Owl.System.cmd("echo", [
               "postgresql://postgres:postgres@127.0.0.1:5432",
               "-tAc",
               "SELECT 1;"
             ])
           end) =~ "$ echo postgresql://postgres:********@127.0.0.1:5432 -tAc 'SELECT 1;'\n"
  end

  test inspect(&Owl.System.shell/2) do
    assert capture_log(fn ->
             Owl.System.shell("echo hello world")
           end) =~ "$ echo hello world\n"
  end
end
