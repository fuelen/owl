defmodule Owl.SpinnerTest do
  use ExUnit.Case, async: true
  import VirtualLiveScreen

  @sleep 5
  @tick_period_ms 30

  test "run with static labels" do
    successful_with_ok_label = "\e[2K\e[32m✔\e[39m OK\e[0m\n"
    failed = "\e[2K\e[31m✖\e[39m\e[0m\n"
    failed_with_error_label = "\e[2K\e[31m✖\e[39m ERROR\e[0m\n"

    capture_frames(fn live_screen_pid, render ->
      opts = [
        refresh_every: @tick_period_ms,
        live_screen_server: live_screen_pid,
        labels: [
          ok: "OK",
          error: "ERROR"
        ]
      ]

      assert Owl.Spinner.run(fn -> :ok end, opts) == :ok
      render.()
      assert_received {:live_screen_frame, ^successful_with_ok_label}
      assert Owl.Spinner.run(fn -> {:ok, true} end, opts) == {:ok, true}
      render.()
      assert_received {:live_screen_frame, ^successful_with_ok_label}
      assert Owl.Spinner.run(fn -> :error end, opts) == :error
      render.()
      assert_received {:live_screen_frame, ^failed_with_error_label}
      assert Owl.Spinner.run(fn -> {:error, :oops} end, opts) == {:error, :oops}
      render.()
      assert_received {:live_screen_frame, ^failed_with_error_label}

      assert_raise(RuntimeError, fn ->
        Owl.Spinner.run(fn -> raise "Boom" end, opts)
      end)

      assert_received {:live_screen_frame, ^failed}
    end)

    refute_received {:live_screen_frame, _}
  end

  test "run" do
    successful = "\e[2K\e[32m✔\e[39m\e[0m\n"
    successful_with_label = fn label -> "\e[2K\e[32m✔\e[39m #{label}\e[0m\n" end
    failed = "\e[2K\e[31m✖\e[39m\e[0m\n"
    failed_with_label = fn label -> "\e[2K\e[31m✖\e[39m #{label}\e[0m\n" end

    inspect_non_nil = fn
      nil -> nil
      term -> inspect(term)
    end

    capture_frames(fn live_screen_pid, render ->
      opts = [
        refresh_every: @tick_period_ms,
        live_screen_server: live_screen_pid,
        labels: [
          processing: "...",
          ok: inspect_non_nil,
          error: inspect_non_nil
        ]
      ]

      assert Owl.Spinner.run(fn -> :ok end, opts) == :ok
      render.()
      assert_received {:live_screen_frame, ^successful}
      assert Owl.Spinner.run(fn -> {:ok, true} end, opts) == {:ok, true}
      render.()
      assert_received {:live_screen_frame, frame}
      assert frame == successful_with_label.("true")
      assert Owl.Spinner.run(fn -> :error end, opts) == :error
      render.()
      assert_received {:live_screen_frame, ^failed}
      assert Owl.Spinner.run(fn -> {:error, :oops} end, opts) == {:error, :oops}

      render.()
      assert_received {:live_screen_frame, frame}
      assert frame == failed_with_label.(":oops")

      assert_raise(RuntimeError, fn ->
        Owl.Spinner.run(fn -> raise "Boom" end, opts)
      end)

      assert_received {:live_screen_frame, ^failed}
    end)

    refute_received {:live_screen_frame, _}
  end

  test "start, update label, stop" do
    id = make_ref()

    capture_frames(fn live_screen_pid, render ->
      Owl.Spinner.start(
        id: id,
        refresh_every: @tick_period_ms,
        live_screen_server: live_screen_pid
      )

      render.()

      assert_received {:live_screen_frame, "\e[2K⠋\n"}
      Process.sleep(@tick_period_ms + @sleep)
      render.()
      assert_received {:live_screen_frame, "\e[1A\e[2K⠙\n"}
      Owl.Spinner.update_label(id: id, label: "Label 1")
      Process.sleep(@tick_period_ms + @sleep)
      render.()
      assert_received {:live_screen_frame, "\e[1A\e[2K⠹ Label 1\n"}
      Owl.Spinner.update_label(id: id, label: "Label 2")
      Process.sleep(@tick_period_ms + @sleep)
      render.()
      assert_received {:live_screen_frame, "\e[1A\e[2K⠸ Label 2\n"}
      Owl.Spinner.stop(id: id, resolution: :ok)
      assert_received {:live_screen_frame, "\e[1A\e[2K\e[32m✔\e[39m\e[0m\n"}
    end)

    refute_received {:live_screen_frame, _}
  end
end
