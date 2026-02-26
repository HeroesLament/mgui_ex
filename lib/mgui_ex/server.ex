defmodule MguiEx.Scene.Server do
  @moduledoc """
  GenServer wrapper for a scene module.

  Handles:
  - Calling the scene's `init/1` to get initial state
  - Calling `render/1` on state changes and sending the tree to Swift
  - Routing UI events from Swift to `handle_event/3`
  - Routing Erlang messages to `handle_info/2`
  - Coalescing rapid state changes (only renders once per message batch)

  Users don't interact with this directly — use `MguiEx.SceneManager`.
  """

  use GenServer
  require Logger

  defstruct [:module, :state, :active]

  # -------------------------------------------------------------------
  # Public API (called by SceneManager)
  # -------------------------------------------------------------------

  def start_link({module, args}) do
    GenServer.start_link(__MODULE__, {module, args}, name: module)
  end

  @doc "Send a UI event to this scene"
  def send_event(scene, node_id, event) do
    GenServer.cast(scene, {:ui_event, node_id, event})
  end

  @doc "Mark this scene as active (will render to popover)"
  def activate(scene) do
    GenServer.cast(scene, :activate)
  end

  @doc "Mark this scene as inactive (still running, won't render)"
  def deactivate(scene) do
    GenServer.cast(scene, :deactivate)
  end

  @doc "Get the current state (for debugging)"
  def get_state(scene) do
    GenServer.call(scene, :get_state)
  end

  # -------------------------------------------------------------------
  # GenServer callbacks
  # -------------------------------------------------------------------

  @impl true
  def init({module, args}) do
    Logger.debug("Scene.Server: starting #{inspect(module)}")

    state = module.init(args)

    {:ok, %__MODULE__{module: module, state: state, active: false}}
  end

  @impl true
  def handle_cast({:ui_event, node_id, event}, %{module: module, state: state} = s) do
    new_state = module.handle_event(node_id, event, state)

    if new_state == state do
      {:noreply, s}
    else
      s = %{s | state: new_state}
      maybe_render(s)
      {:noreply, s}
    end
  end

  def handle_cast(:activate, s) do
    s = %{s | active: true}
    do_render(s)
    {:noreply, s}
  end

  def handle_cast(:deactivate, s) do
    {:noreply, %{s | active: false}}
  end

  @impl true
  def handle_call(:get_state, _from, s) do
    {:reply, s.state, s}
  end

  @impl true
  def handle_info(msg, %{module: module, state: state} = s) do
    if function_exported?(module, :handle_info, 2) do
      case module.handle_info(msg, state) do
        {:noreply, new_state} ->
          if new_state == state do
            {:noreply, s}
          else
            s = %{s | state: new_state}
            maybe_render(s)
            {:noreply, s}
          end

        {:stop, reason, new_state} ->
          {:stop, reason, %{s | state: new_state}}

        other ->
          Logger.warning("Scene.Server(#{inspect(module)}): handle_info returned unexpected: #{inspect(other)}")
          {:noreply, s}
      end
    else
      Logger.debug("Scene.Server(#{inspect(module)}): ignoring #{inspect(msg)}")
      {:noreply, s}
    end
  end

  # -------------------------------------------------------------------
  # Private
  # -------------------------------------------------------------------

  defp maybe_render(%{active: true} = s), do: do_render(s)
  defp maybe_render(_s), do: :ok

  defp do_render(%{module: module, state: state}) do
    MguiEx.View.reset_ids()
    tree = module.render(state)

    opts =
      if function_exported?(module, :status_bar, 1) do
        module.status_bar(state)
      else
        []
      end

    MguiEx.SwiftPort.render(tree, opts)
  end
end
