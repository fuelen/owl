defmodule Owl.TaskTest do
  use ExUnit.Case, async: true

  test inspect(&Owl.Task.run/1) do
    assert {:ok, 1} = Owl.Task.run(fn -> 1 end)
    assert {:exit, _} = Owl.Task.run(fn -> raise "boom" end)
  end
end
