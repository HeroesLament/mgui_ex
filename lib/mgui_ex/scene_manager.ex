defmodule MguiEx.SceneManager do
  @moduledoc """
  Manages the lifecycle of scenes and routes events between Swift and scenes.

  The SceneManager:
  - Starts scenes as supervised GenServer processes
  - Tracks which scene is currently active (displayed in popover)
  - Routes UI events from SwiftPort to the active scene
  - Handles scene switching (deactivate old, activate new)

  ## Usage

      # In your application supervisor:
      children = [
        MguiEx.SwiftPort,
        {MguiEx.SceneManager, scenes: [Auther.LoginScene, Auther.StatusScene]}
      ]

      # Or start manually:
      MguiEx.SceneManager.start_link(scenes: [MyApp.MainScene])

      # Switch scenes:
      MguiEx.SceneManager.activate(Auther.StatusScene)
  """

  use GenServer
  require Logger

  defstruct [:active_scene, :scenes]

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Activate a scene, making it the visible scene in the popover.
  The previously active scene is deactivated but keeps running.
  """
  def activate(scene_module) do
    GenServer.cast(__MODULE__, {:activate, scene_module})
  end

  @doc "Get the currently active scene module"
  def active_scene do
    GenServer.call(__MODULE__, :active_scene)
  end

  @doc "Send a UI event to the active scene"
  def route_event(node_id, event) do
    GenServer.cast(__MODULE__, {:route_event, node_id, event})
  end

  # -------------------------------------------------------------------
  # GenServer callbacks
  # -------------------------------------------------------------------

  @impl true
  def init(opts) do
    scenes = Keyword.get(opts, :scenes, [])
    initial = Keyword.get(opts, :initial, List.first(scenes))

    # Start all scenes
    for scene_module <- scenes do
      args = Keyword.get(opts, :args, [])
      {:ok, _pid} = MguiEx.Scene.Server.start_link({scene_module, args})
      Logger.debug("SceneManager: started #{inspect(scene_module)}")
    end

    # Configure SwiftPort to route events through us
    configure_event_routing()

    # Activate the initial scene
    if initial do
      MguiEx.Scene.Server.activate(initial)
      Logger.info("SceneManager: activated #{inspect(initial)}")
    end

    {:ok, %__MODULE__{active_scene: initial, scenes: scenes}}
  end

  @impl true
  def handle_cast({:activate, scene_module}, state) do
    # Deactivate current
    if state.active_scene && state.active_scene != scene_module do
      MguiEx.Scene.Server.deactivate(state.active_scene)
    end

    # Activate new
    MguiEx.Scene.Server.activate(scene_module)
    Logger.info("SceneManager: switched to #{inspect(scene_module)}")

    {:noreply, %{state | active_scene: scene_module}}
  end

  def handle_cast({:route_event, node_id, event}, state) do
    if state.active_scene do
      MguiEx.Scene.Server.send_event(state.active_scene, node_id, event)
    else
      Logger.warning("SceneManager: event #{node_id} -> #{event} but no active scene")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:active_scene, _from, state) do
    {:reply, state.active_scene, state}
  end

  # -------------------------------------------------------------------
  # Private
  # -------------------------------------------------------------------

  defp configure_event_routing do
    # We need to tell SwiftPort to send events to us.
    # This is done by restarting SwiftPort with our event handler,
    # or by updating it if it's already running.
    #
    # For now, we register a global event handler that the SwiftPort
    # checks on each event.
    :persistent_term.put(:mgui_ex_event_handler, fn node_id, event ->
      route_event(node_id, event)
    end)
  end
end
