defmodule MguiEx.SwiftPort do
  @moduledoc """
  Manages the Port connection to the MguiExRuntime Swift binary.

  Sends MessagePack-encoded messages to Swift via stdin,
  receives events from Swift via stdout.

  Uses `{:packet, 4}` which makes Erlang automatically handle
  4-byte big-endian length prefix framing on both directions.
  """

  use GenServer
  require Logger

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Send a full render message to Swift.

  ## Options
    * `:title` - status bar title text
    * `:icon` - SF Symbol name for status bar icon
    * `:menu` - list of menu item maps (from MguiEx.View.menu_item/2)

  ## Example

      import MguiEx.View

      tree = vstack([spacing: 8], [
        text("Hello", font: "headline"),
        text_field("Name", id: "tf-name", placeholder: "Your name"),
        button("OK", id: "btn-ok")
      ]) |> pad(16)

      menu = [
        menu_item("Preferences...", id: "menu-prefs", shortcut: "cmd+,"),
        menu_divider(),
        menu_item("Quit", id: "menu-quit", shortcut: "cmd+q")
      ]

      MguiEx.SwiftPort.render(tree, title: "My App", icon: "star.fill", menu: menu)
  """
  def render(tree, opts \\ []) do
    GenServer.cast(__MODULE__, {:render, tree, opts})
  end

  @doc "Send a quit message to Swift, terminating the runtime."
  def quit do
    GenServer.cast(__MODULE__, :quit)
  end

  @doc "Send a notification to the Swift side for display."
  def send_notification(notification_map) do
    GenServer.cast(__MODULE__, {:send_notification, notification_map})
  end

  @doc "Cancel a notification on the Swift side."
  def cancel_notification(notification_id) do
    GenServer.cast(__MODULE__, {:cancel_notification, notification_id})
  end

  # -------------------------------------------------------------------
  # GenServer callbacks
  # -------------------------------------------------------------------

  @impl true
  def init(opts) do
    binary = find_binary(opts)

    port =
      Port.open({:spawn_executable, to_charlist(binary)}, [
        :binary,
        :exit_status,
        {:packet, 4}
      ])

    Logger.info("MguiEx.SwiftPort: started #{binary}, port=#{inspect(port)}")

    {:ok, %{port: port, event_handler: Keyword.get(opts, :on_event, nil)}}
  end

  @impl true
  def handle_cast({:render, tree, opts}, state) do
    status_bar = %{
      "title" => Keyword.get(opts, :title),
      "icon" => Keyword.get(opts, :icon)
    }

    msg = %{
      "type" => "render",
      "payload" => %{
        "root" => tree,
        "statusBar" => status_bar,
        "menu" => Keyword.get(opts, :menu)
      }
    }

    send_msg(state.port, msg)
    {:noreply, state}
  end

  def handle_cast(:quit, state) do
    send_msg(state.port, %{"type" => "quit", "payload" => %{}})
    {:noreply, state}
  end

  def handle_cast({:send_notification, notification_map}, state) do
    send_msg(state.port, %{"type" => "notify", "payload" => notification_map})
    {:noreply, state}
  end

  def handle_cast({:cancel_notification, notification_id}, state) do
    send_msg(state.port, %{"type" => "cancel_notification", "payload" => %{"id" => notification_id}})
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    case Msgpax.unpack(data) do
      {:ok, %{"type" => "event", "nodeId" => node_id, "event" => event}} ->
        Logger.debug("MguiEx.SwiftPort: event #{node_id} -> #{event}")

        # Route through SceneManager if configured, otherwise use direct handler
        cond do
          handler = try_get_global_handler() ->
            handler.(node_id, event)

          state.event_handler ->
            state.event_handler.(node_id, event)

          true ->
            :ok
        end

      {:ok, %{"type" => "notification", "id" => notif_id, "event" => notif_event} = msg} ->
        Logger.debug("MguiEx.SwiftPort: notification #{notif_id} -> #{notif_event}")
        route_notification_event(notif_id, notif_event, msg)

      {:ok, other} ->
        Logger.warning("MguiEx.SwiftPort: unexpected message #{inspect(other)}")

      {:error, reason} ->
        Logger.error("MguiEx.SwiftPort: msgpack decode error #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("MguiEx.SwiftPort: Swift process exited with status #{status}")
    {:stop, {:swift_exit, status}, state}
  end

  def handle_info(msg, state) do
    Logger.debug("MguiEx.SwiftPort: unhandled message #{inspect(msg)}")
    {:noreply, state}
  end

  # -------------------------------------------------------------------
  # Private
  # -------------------------------------------------------------------

  defp send_msg(port, msg) do
    data = Msgpax.pack!(msg, iodata: false)
    Port.command(port, data)
  end

  defp find_binary(opts) do
    cond do
      path = Keyword.get(opts, :binary) ->
        path

      # Prefer .app bundle (has bundle identity for notifications, etc.)
      File.exists?(dev_app_binary()) ->
        dev_app_binary()

      # Bare binary fallback (AppleScript notifications only)
      File.exists?(dev_bare_binary()) ->
        dev_bare_binary()

      # Dep .app bundle (when mgui_ex is a dep, built via mix mgui_ex.build)
      File.exists?(dep_app_binary()) ->
        dep_app_binary()

      # Dep bare binary
      File.exists?(dep_bare_binary()) ->
        dep_bare_binary()

      # Production: check priv/ for .app bundle first
      File.exists?(priv_app_binary()) ->
        priv_app_binary()

      true ->
        priv_bare_binary()
    end
  end

  defp dev_app_binary do
    Path.join([File.cwd!(), "swift", ".build", "MguiExRuntime.app", "Contents", "MacOS", "MguiExRuntime"])
  end

  defp dev_bare_binary do
    Path.join([File.cwd!(), "swift", ".build", "arm64-apple-macosx", "debug", "MguiExRuntime"])
  end

  defp priv_app_binary do
    :code.priv_dir(:mgui_ex)
    |> to_string()
    |> Path.join(Path.join(["MguiExRuntime.app", "Contents", "MacOS", "MguiExRuntime"]))
  end

  defp priv_bare_binary do
    :code.priv_dir(:mgui_ex)
    |> to_string()
    |> Path.join("mgui_ex_runtime")
  end

  defp dep_app_binary do
    Path.join([File.cwd!(), "deps", "mgui_ex", "swift", ".build", "MguiExRuntime.app", "Contents", "MacOS", "MguiExRuntime"])
  end

  defp dep_bare_binary do
    Path.join([File.cwd!(), "deps", "mgui_ex", "swift", ".build", "arm64-apple-macosx", "debug", "MguiExRuntime"])
  end

  defp try_get_global_handler do
    try do
      :persistent_term.get(:mgui_ex_event_handler)
    rescue
      ArgumentError -> nil
    end
  end

  defp route_notification_event(notif_id, "delivered", _msg) do
    case Registry.lookup(MguiEx.Notification.Registry, notif_id) do
      [{pid, _}] -> :gen_statem.cast(pid, {:delivered})
      [] -> Logger.warning("MguiEx.SwiftPort: no notification process for #{notif_id}")
    end
  end

  defp route_notification_event(notif_id, "interacted", msg) do
    action = Map.get(msg, "action", "default")
    text = Map.get(msg, "text")
    MguiEx.Notification.handle_interaction(notif_id, action, text)
  end

  defp route_notification_event(notif_id, "dismissed", _msg) do
    case Registry.lookup(MguiEx.Notification.Registry, notif_id) do
      [{pid, _}] -> :gen_statem.cast(pid, :dismiss)
      [] -> Logger.warning("MguiEx.SwiftPort: no notification process for #{notif_id}")
    end
  end

  defp route_notification_event(notif_id, "error", msg) do
    reason = Map.get(msg, "reason", "unknown")
    Logger.error("MguiEx.SwiftPort: notification #{notif_id} error: #{reason}")
    # Notify the FSM listener about the error
    case Registry.lookup(MguiEx.Notification.Registry, notif_id) do
      [{pid, _}] ->
        # The listener will get {:notification, id, :error, %{reason: reason}}
        # We don't have a state for errors in the FSM — just notify directly
        data = :gen_statem.call(pid, :status) |> elem(1)
        if data.notify, do: send(data.notify, {:notification, notif_id, :error, %{reason: reason}})
      [] -> :ok
    end
  end

  defp route_notification_event(notif_id, event, _msg) do
    Logger.warning("MguiEx.SwiftPort: unknown notification event #{event} for #{notif_id}")
  end
end
