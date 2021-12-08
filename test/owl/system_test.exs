defmodule Owl.SystemTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test inspect(&Owl.System.cmd/3) do
    assert capture_log(fn ->
             Owl.System.cmd("echo", [])
           end) =~ "$ echo"

    assert capture_log(fn ->
             Owl.System.cmd("echo", ["http://example.com"])
           end) =~ "$ echo http://example.com"

    assert capture_log(fn ->
             Owl.System.cmd("echo", [
               "postgresql://postgres:postgres@127.0.0.1:5432",
               "-tAc",
               "SELECT 1;"
             ])
           end) =~ "$ echo postgresql://postgres:********@127.0.0.1:5432 -tAc 'SELECT 1;'"
  end
end
