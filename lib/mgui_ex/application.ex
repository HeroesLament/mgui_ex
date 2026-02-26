defmodule MguiEx.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: MguiEx.Notification.Registry},
      {DynamicSupervisor, name: MguiEx.Notification.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MguiEx.Supervisor)
  end
end
