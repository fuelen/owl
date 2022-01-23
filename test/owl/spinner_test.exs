defmodule Owl.SpinnerTest do
  use ExUnit.Case, async: true
  import CaptureIOFrames

  @sleep 5
  @tick_period_ms 30

  test "run" do
    successful = "\e[2K\e[32m✔\e[39m\e[0m\n"
    successful_with_label = fn label -> "\e[2K\e[32m✔\e[39m #{label}\e[0m\n" end
    failed = "\e[2K\e[31m✖\e[39m\e[0m\n"
    failed_with_label = fn label -> "\e[2K\e[31m✖\e[39m #{label}\e[0m\n" end

    inspect_non_nil = fn
      nil -> nil
      term -> inspect(term)
    end

    assert capture_io_frames(fn live_screen_pid, render ->
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
             assert Owl.Spinner.run(fn -> {:ok, true} end, opts) == {:ok, true}
             render.()
             assert Owl.Spinner.run(fn -> :error end, opts) == :error
             render.()
             assert Owl.Spinner.run(fn -> {:error, :oops} end, opts) == {:error, :oops}

             render.()

             assert_raise(RuntimeError, fn ->
               Owl.Spinner.run(fn -> raise "Boom" end, opts)
             end)
           end) == [
             successful,
             successful_with_label.("true"),
             failed,
             failed_with_label.(":oops"),
             failed
           ]
  end

  test "start, update label, stop" do
    id = make_ref()

    frames =
      capture_io_frames(fn live_screen_pid, render ->
        Owl.Spinner.start(
          id: id,
          refresh_every: @tick_period_ms,
          live_screen_server: live_screen_pid
        )

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
      end)

    assert frames == [
             "\e[2K⠋\n",
             "\e[1A\e[2K⠙\n",
             "\e[1A\e[2K⠹ Label 1\n",
             "\e[1A\e[2K⠸ Label 2\n",
             "\e[1A\e[2K\e[32m✔\e[39m\e[0m\n"
           ]
  end
end
