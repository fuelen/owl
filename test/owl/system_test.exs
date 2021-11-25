defmodule Owl.SystemTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  test inspect(&Owl.System.cmd/3) do
    assert capture_io(fn ->
             Owl.System.cmd("echo", [])
           end) == "\e[90m$ echo\e[39m\e[49m\e[0m\n"

    assert capture_io(fn ->
             Owl.System.cmd("echo", ["http://example.com"])
           end) == "\e[90m$ echo http://example.com\e[39m\e[49m\e[0m\n"

    assert capture_io(fn ->
             Owl.System.cmd("echo", [
               "postgresql://postgres:postgres@127.0.0.1:5432",
               "-tAc",
               "SELECT 1;"
             ])
           end) ==
             "\e[90m$ echo postgresql://postgres:********@127.0.0.1:5432 -tAc 'SELECT 1;'\e[39m\e[49m\e[0m\n"
  end
end
