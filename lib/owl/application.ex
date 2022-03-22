defmodule Owl.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Owl.WidgetsRegistry},
      {Owl.LiveScreen, name: Owl.LiveScreen},
      {DynamicSupervisor, strategy: :one_for_one, name: Owl.WidgetsSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Owl.DaemonsSupervisor},
      {Task.Supervisor, strategy: :one_for_one, name: Owl.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
