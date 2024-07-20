defmodule Owl.Task do
  @moduledoc """
  Run task using internal supervision tree.
  """

  @doc """
  Runs a function as a task under supervision tree.

  This is useful when you need graceful shutdown in simple scripts, where Owl is installed
  using `Mix.install/2`.

  ## Example

      # content of ping.exs file, run as `elixir --no-halt ping.exs`
      Mix.install([:owl])

      Owl.Task.run(fn ->
        Owl.System.daemon_cmd("ping", ["8.8.8.8"], fn ->
          Process.sleep(3000)
          2 + 2
        end)
      end

      System.stop()

  """
  @spec run((-> result)) :: {:ok, result} | {:exit, term()} when result: any()
  def run(function) do
    task = Task.Supervisor.async_nolink(Owl.TaskSupervisor, function)
    Task.yield(task, :infinity)
  end
end
