defmodule Owl.Daemon do
  @moduledoc false
  use GenServer, restart: :temporary
  require Logger

  def start(args) do
    DynamicSupervisor.start_child(Owl.DaemonsSupervisor, {__MODULE__, args})
  end

  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  @impl true
  def init(args) do
    command = Keyword.fetch!(args, :command)
    command_args = Keyword.fetch!(args, :args)
    executable = System.find_executable(command)
    Owl.System.Helpers.log_shell_command(command, command_args)

    Process.flag(:trap_exit, true)

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: command_args
      ])

    prefix =
      Keyword.get_lazy(args, :prefix, fn ->
        Owl.Data.tag([command, ": "], :cyan)
      end)

    port_info = Port.info(port)
    Logger.debug("Started daemon #{command} with OS pid #{port_info[:os_pid]}")

    {:ok, %{device: Keyword.get(args, :device, :stdio), port: port, prefix: prefix}}
  end

  @impl true
  def terminate({:premature_port_exit, _status}, _state) do
    :noop
  end

  def terminate(_reason, %{port: port}) do
    port_info = Port.info(port)

    Owl.System.cmd("kill", [to_string(port_info[:os_pid])])
  end

  @impl true
  def handle_info({port, {:data, text_lines}}, %{port: port} = state) do
    text_lines
    |> String.trim_trailing("\n")
    |> Owl.Data.add_prefix([state.prefix, " "])
    |> Owl.IO.puts(state.device)

    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    {:stop, {:premature_port_exit, status}, state}
  end

  # terminate when caller dies
  def handle_info({:EXIT, _pid, _msg}, state) do
    {:stop, :normal, state}
  end
end
