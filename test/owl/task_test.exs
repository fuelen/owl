defmodule Owl.TaskTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test inspect(&Owl.Task.run/1) do
    assert {:ok, 1} = Owl.Task.run(fn -> 1 end)

    assert capture_log(fn ->
             assert {:exit, _} = Owl.Task.run(fn -> raise "boom" end)
           end) =~ "(RuntimeError) boom"
  end
end
