defmodule Owl.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Owl.ProgressBar.Registry},
      {Owl.LiveScreen, name: Owl.LiveScreen},
      {DynamicSupervisor, strategy: :one_for_one, name: Owl.ProgressBar.Supervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
