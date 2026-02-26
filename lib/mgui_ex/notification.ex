defmodule MguiEx.Notification do
  @moduledoc """
  FSM for managing the lifecycle of a macOS notification.

  Each notification is a `:gen_statem` process that tracks its state
  through the notification lifecycle:

      :idle → :pending → :delivered → :interacted / :dismissed
                                    → :expired
      :idle → :scheduled → :pending → ...
      any   → :cancelled

  ## Usage

      # Push immediately
      {:ok, pid} = MguiEx.Notification.start_link("ticket-expiry",
        title: "Kerberos Ticket Expiring",
        body: "Your ticket expires in 1 hour",
        notify: self()
      )
      MguiEx.Notification.push(pid)

      # Schedule for later
      {:ok, pid} = MguiEx.Notification.start_link("daily-check",
        title: "Ticket Check",
        body: "Time to verify your Kerberos tickets",
        notify: self()
      )
      MguiEx.Notification.schedule(pid, {:interval, 3600})  # 1 hour
      MguiEx.Notification.schedule(pid, {:date, ~U[2026-02-25 17:00:00Z]})
      MguiEx.Notification.schedule(pid, {:daily, "09:00"})

      # Cancel
      MguiEx.Notification.cancel(pid)

      # The `notify` process receives state transition messages:
      #   {:notification, id, :pending, data}
      #   {:notification, id, :delivered, data}
      #   {:notification, id, :interacted, %{action: "default"}}
      #   {:notification, id, :interacted, %{action: "renew", text: "..."}}
      #   {:notification, id, :dismissed, data}
      #   {:notification, id, :cancelled, data}
      #   {:notification, id, :expired, data}
      #   {:notification, id, :error, %{reason: reason}}

  ## Actions

  Notifications can have interactive action buttons:

      MguiEx.Notification.start_link("ticket-expiry",
        title: "Ticket Expiring",
        body: "Expires in 1 hour",
        actions: [
          %{id: "renew", title: "Renew Now"},
          %{id: "snooze", title: "Remind in 30min"},
          %{id: "dismiss", title: "Dismiss", destructive: true}
        ],
        notify: self()
      )

  ## Dev mode

  When running outside a .app bundle (development), notifications fall back
  to AppleScript `display notification`. In this mode, scheduling, actions,
  and interaction callbacks are not available — only immediate push works,
  and the FSM transitions directly from :pending to :delivered.
  """

  @behaviour :gen_statem

  require Logger

  defstruct [
    :id,
    :title,
    :body,
    :subtitle,
    :sound,
    :actions,
    :notify,
    :trigger,
    :timer_ref,
    :created_at
  ]

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  @doc "Start a notification FSM process."
  def start_link(id, opts \\ []) do
    config = %__MODULE__{
      id: id,
      title: Keyword.fetch!(opts, :title),
      body: Keyword.get(opts, :body),
      subtitle: Keyword.get(opts, :subtitle),
      sound: Keyword.get(opts, :sound, true),
      actions: Keyword.get(opts, :actions, []),
      notify: Keyword.get(opts, :notify),
      created_at: DateTime.utc_now()
    }

    :gen_statem.start_link({:via, Registry, {MguiEx.Notification.Registry, id}}, __MODULE__, config, [])
  end

  @doc """
  Create and push a notification in one call.

  Starts the FSM under the DynamicSupervisor and immediately pushes it.
  Returns `{:ok, pid}`.
  """
  def notify(id, opts) do
    opts = Keyword.put_new(opts, :notify, self())

    # If a notification with this ID is still alive, cancel it first
    case Registry.lookup(MguiEx.Notification.Registry, id) do
      [{pid, _}] ->
        :gen_statem.stop(pid, :normal, 100)
      [] ->
        :ok
    end

    {:ok, pid} = DynamicSupervisor.start_child(
      MguiEx.Notification.Supervisor,
      {__MODULE__, {id, opts}}
    )
    push(pid)
    {:ok, pid}
  end

  @doc "Child spec for DynamicSupervisor."
  def child_spec({id, opts}) do
    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [id, opts]},
      restart: :temporary
    }
  end

  @doc "Push the notification immediately."
  def push(id_or_pid) do
    :gen_statem.cast(resolve(id_or_pid), :push)
  end

  @doc """
  Schedule the notification for future delivery.

  Triggers:
    * `{:interval, seconds}` — fire after N seconds
    * `{:date, datetime}` — fire at a specific DateTime
    * `{:daily, "HH:MM"}` — fire daily at the given time
  """
  def schedule(id_or_pid, trigger) do
    :gen_statem.cast(resolve(id_or_pid), {:schedule, trigger})
  end

  @doc "Cancel the notification (from any state)."
  def cancel(id_or_pid) do
    :gen_statem.cast(resolve(id_or_pid), :cancel)
  end

  @doc "Get the current state and data."
  def status(id_or_pid) do
    :gen_statem.call(resolve(id_or_pid), :status)
  end

  @doc "Called by SwiftPort when a notification interaction event arrives."
  def handle_interaction(notification_id, action_id, user_text \\ nil) do
    case Registry.lookup(MguiEx.Notification.Registry, notification_id) do
      [{pid, _}] ->
        :gen_statem.cast(pid, {:interaction, action_id, user_text})
      [] ->
        Logger.warning("Notification.handle_interaction: unknown notification #{notification_id}")
    end
  end

  # -------------------------------------------------------------------
  # gen_statem callbacks
  # -------------------------------------------------------------------

  @impl true
  def callback_mode, do: :state_functions

  @impl true
  def init(%__MODULE__{} = data) do
    Logger.debug("Notification(#{data.id}): created")
    {:ok, :idle, data}
  end

  # -------------------------------------------------------------------
  # State: :idle
  # -------------------------------------------------------------------

  def idle(:cast, :push, data) do
    Logger.debug("Notification(#{data.id}): idle → pending")
    do_push(data)
    notify_listener(data, :pending)
    {:next_state, :pending, data}
  end

  def idle(:cast, {:schedule, trigger}, data) do
    Logger.debug("Notification(#{data.id}): idle → scheduled (#{inspect(trigger)})")
    timer_ref = schedule_timer(trigger)
    data = %{data | trigger: trigger, timer_ref: timer_ref}
    notify_listener(data, :scheduled)
    {:next_state, :scheduled, data}
  end

  def idle(:cast, :cancel, data) do
    Logger.debug("Notification(#{data.id}): idle → cancelled")
    notify_listener(data, :cancelled)
    {:stop, :normal, data}
  end

  def idle({:call, from}, :status, data) do
    {:keep_state, data, [{:reply, from, {:idle, data}}]}
  end

  # -------------------------------------------------------------------
  # State: :scheduled
  # -------------------------------------------------------------------

  def scheduled(:cast, :cancel, data) do
    Logger.debug("Notification(#{data.id}): scheduled → cancelled")
    cancel_timer(data.timer_ref)
    notify_listener(data, :cancelled)
    {:stop, :normal, data}
  end

  def scheduled(:info, :fire, data) do
    Logger.debug("Notification(#{data.id}): scheduled → pending (timer fired)")
    do_push(data)
    notify_listener(data, :pending)
    {:next_state, :pending, %{data | timer_ref: nil}}
  end

  def scheduled(:cast, {:schedule, trigger}, data) do
    # Reschedule — cancel old timer, set new one
    cancel_timer(data.timer_ref)
    timer_ref = schedule_timer(trigger)
    {:keep_state, %{data | trigger: trigger, timer_ref: timer_ref}}
  end

  def scheduled(:cast, :push, data) do
    # Push immediately, cancel scheduled timer
    cancel_timer(data.timer_ref)
    do_push(data)
    notify_listener(data, :pending)
    {:next_state, :pending, %{data | timer_ref: nil}}
  end

  def scheduled({:call, from}, :status, data) do
    {:keep_state, data, [{:reply, from, {:scheduled, data}}]}
  end

  # -------------------------------------------------------------------
  # State: :pending
  # -------------------------------------------------------------------

  def pending(:cast, {:delivered}, data) do
    Logger.debug("Notification(#{data.id}): pending → delivered")
    notify_listener(data, :delivered)
    {:next_state, :delivered, data}
  end

  def pending(:cast, {:interaction, action_id, user_text}, data) do
    # Can go directly from pending to interacted (fast tap)
    Logger.debug("Notification(#{data.id}): pending → interacted (#{action_id})")
    interaction_data = %{action: action_id, text: user_text}
    notify_listener(data, :interacted, interaction_data)
    {:next_state, :interacted, data}
  end

  def pending(:cast, :cancel, data) do
    Logger.debug("Notification(#{data.id}): pending → cancelled")
    do_cancel_on_swift(data)
    notify_listener(data, :cancelled)
    {:stop, :normal, data}
  end

  # In dev mode (AppleScript), we auto-transition to delivered
  # since there's no delivery callback
  def pending(:state_timeout, :auto_deliver, data) do
    Logger.debug("Notification(#{data.id}): pending → delivered (auto, dev mode)")
    notify_listener(data, :delivered)
    {:next_state, :delivered, data}
  end

  def pending({:call, from}, :status, data) do
    {:keep_state, data, [{:reply, from, {:pending, data}}]}
  end

  # -------------------------------------------------------------------
  # State: :delivered
  # -------------------------------------------------------------------

  def delivered(:cast, {:interaction, action_id, user_text}, data) do
    Logger.debug("Notification(#{data.id}): delivered → interacted (#{action_id})")
    interaction_data = %{action: action_id, text: user_text}
    notify_listener(data, :interacted, interaction_data)
    {:next_state, :interacted, data}
  end

  def delivered(:cast, :dismiss, data) do
    Logger.debug("Notification(#{data.id}): delivered → dismissed")
    notify_listener(data, :dismissed)
    {:stop, :normal, data}
  end

  def delivered(:cast, :cancel, data) do
    Logger.debug("Notification(#{data.id}): delivered → cancelled")
    do_cancel_on_swift(data)
    notify_listener(data, :cancelled)
    {:stop, :normal, data}
  end

  def delivered({:call, from}, :status, data) do
    {:keep_state, data, [{:reply, from, {:delivered, data}}]}
  end

  # -------------------------------------------------------------------
  # State: :interacted (terminal)
  # -------------------------------------------------------------------

  def interacted({:call, from}, :status, data) do
    {:keep_state, data, [{:reply, from, {:interacted, data}}]}
  end

  def interacted(:cast, _, data) do
    {:keep_state, data}
  end

  # -------------------------------------------------------------------
  # Private
  # -------------------------------------------------------------------

  defp resolve(pid) when is_pid(pid), do: pid
  defp resolve(id) when is_binary(id) do
    case Registry.lookup(MguiEx.Notification.Registry, id) do
      [{pid, _}] -> pid
      [] -> raise "No notification process for id: #{id}"
    end
  end

  defp notify_listener(%{notify: nil}, _state, _extra), do: :ok
  defp notify_listener(%{notify: pid, id: id}, state, extra) do
    send(pid, {:notification, id, state, extra})
  end

  defp notify_listener(data, state), do: notify_listener(data, state, %{})

  defp do_push(data) do
    # Send "notify" message to Swift side
    msg = %{
      "id" => data.id,
      "title" => data.title,
      "body" => data.body,
      "subtitle" => data.subtitle,
      "sound" => data.sound,
      "actions" => Enum.map(data.actions || [], fn action ->
        %{
          "id" => Map.get(action, :id, "default"),
          "title" => Map.get(action, :title, "OK"),
          "destructive" => Map.get(action, :destructive, false)
        }
      end)
    }

    MguiEx.SwiftPort.send_notification(msg)
  end

  defp do_cancel_on_swift(data) do
    MguiEx.SwiftPort.cancel_notification(data.id)
  end

  defp schedule_timer({:interval, seconds}) when is_number(seconds) do
    Process.send_after(self(), :fire, trunc(seconds * 1000))
  end

  defp schedule_timer({:date, %DateTime{} = dt}) do
    now = DateTime.utc_now()
    diff_ms = max(DateTime.diff(dt, now, :millisecond), 0)
    Process.send_after(self(), :fire, diff_ms)
  end

  defp schedule_timer({:daily, time_string}) when is_binary(time_string) do
    # Parse "HH:MM", calculate ms until next occurrence
    [h, m] = String.split(time_string, ":") |> Enum.map(&String.to_integer/1)
    now = DateTime.utc_now()
    target_today = %{now | hour: h, minute: m, second: 0}

    target =
      if DateTime.compare(target_today, now) == :gt do
        target_today
      else
        # Tomorrow
        DateTime.add(target_today, 86400, :second)
      end

    diff_ms = max(DateTime.diff(target, now, :millisecond), 0)
    Process.send_after(self(), :fire, diff_ms)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)
end
