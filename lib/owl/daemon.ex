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
    command_env = Keyword.get(args, :env, [])
    executable = System.find_executable(command)
    Owl.System.Helpers.log_cmd(command_env, command, command_args)

    command_env =
      command_env
      |> Owl.System.Helpers.normalize_env()
      # https://github.com/elixir-lang/elixir/blob/a64d42f5d3cb6c32752af9d3312897e8cd5bb7ec/lib/elixir/lib/system.ex#L1099
      |> Enum.map(fn
        {k, nil} -> {String.to_charlist(k), false}
        {k, v} -> {String.to_charlist(k), String.to_charlist(v)}
      end)

    command_args = Owl.System.Helpers.normalize_cmd_args(command_args)

    {handle_data_state, handle_data_callback} =
      case Keyword.get(args, :handle_data) do
        nil -> {nil, &noop_handle_data_callback/2}
        {initial_state, callback} -> {initial_state, callback}
      end

    Process.flag(:trap_exit, true)

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: command_args,
        env: command_env
      ])

    prefix =
      Keyword.get_lazy(args, :prefix, fn ->
        Owl.Data.tag([command, ": "], :cyan)
      end)

    port_info = Port.info(port)
    Logger.debug("Started daemon #{command} with OS pid #{port_info[:os_pid]}")

    {:ok,
     %{
       device: Keyword.get(args, :device, :stdio),
       port: port,
       prefix: prefix,
       handle_data_callback: handle_data_callback,
       handle_data_state: handle_data_state
     }}
  end

  defp noop_handle_data_callback(_data, state), do: state

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
    handle_data_state = state.handle_data_callback.(text_lines, state.handle_data_state)

    text_lines
    |> String.trim_trailing("\n")
    |> Owl.Data.add_prefix([state.prefix, " "])
    |> Owl.IO.puts(state.device)

    {:noreply, %{state | handle_data_state: handle_data_state}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    {:stop, {:premature_port_exit, status}, state}
  end

  # terminate when caller dies
  def handle_info({:EXIT, _pid, _msg}, state) do
    {:stop, :normal, state}
  end
end
