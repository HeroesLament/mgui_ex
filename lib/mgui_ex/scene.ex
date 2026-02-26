defmodule MguiEx.Scene do
  @moduledoc """
  Behaviour for defining mgui_ex scenes.

  A scene is a self-contained screen with state, event handling, and a view
  function. Each scene runs as a GenServer process. One scene is active in
  the popover at a time, but all scenes can receive messages (e.g. timers,
  PubSub) even when backgrounded.

  ## Usage

      defmodule Auther.LoginScene do
        use MguiEx.Scene

        def init(_opts) do
          %{username: "", password: "", error: nil, loading: false}
        end

        def render(state) do
          import MguiEx.View

          vstack([spacing: 12], [
            text("Sign In") |> font("title2"),
            text_field("Username", id: "tf-user", placeholder: "user@REALM.COM"),
            secure_field("Password", id: "tf-pass", placeholder: "Password"),
            if state.error do
              text(state.error) |> fg("red") |> font("caption")
            end,
            button("Sign In", id: "btn-signin")
              |> bg("accentColor") |> fg("white") |> rounded(8)
          ]) |> pad(16)
        end

        def handle_event("tf-user", "change:" <> value, state) do
          %{state | username: value}
        end

        def handle_event("tf-pass", "change:" <> value, state) do
          %{state | password: value}
        end

        def handle_event("btn-signin", "tap", state) do
          # Kick off async kinit
          self = self()
          Task.start(fn ->
            result = System.cmd("kinit", [state.username], ...)
            send(self, {:kinit_result, result})
          end)
          %{state | loading: true}
        end

        def handle_event(_id, _event, state), do: state

        def handle_info({:kinit_result, {_, 0}}, state) do
          MguiEx.SceneManager.activate(Auther.StatusScene)
          {:noreply, %{state | loading: false}}
        end

        def handle_info({:kinit_result, {output, _}}, state) do
          {:noreply, %{state | loading: false, error: "Authentication failed"}}
        end
      end

  ## Callbacks

  - `init/1` — Called once at startup. Returns initial state (any term).
  - `render/1` — Pure function of state → view tree (map). Called after every state change.
  - `handle_event/3` — `(node_id, event_string, state) → new_state`. UI events from Swift.
  - `handle_info/2` — `(message, state) → {:noreply, new_state}`. Erlang messages (optional).

  ## Status Bar

  Scenes can also define:
  - `status_bar/1` — `(state) → keyword()` with `:title`, `:icon`, `:menu` keys.
    If not defined, the last status bar config is preserved.
  """

  @doc "Initialize the scene's state. Called once when the scene starts."
  @callback init(args :: term()) :: state :: term()

  @doc "Render the current state as a view tree map."
  @callback render(state :: term()) :: map()

  @doc "Handle a UI event. Returns updated state."
  @callback handle_event(node_id :: String.t(), event :: String.t(), state :: term()) :: term()

  @doc "Handle an Erlang message. Returns `{:noreply, new_state}`."
  @callback handle_info(msg :: term(), state :: term()) :: {:noreply, term()}

  @doc "Return status bar config for this scene. Keys: :title, :icon, :menu"
  @callback status_bar(state :: term()) :: keyword()

  @optional_callbacks [handle_info: 2, status_bar: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour MguiEx.Scene
    end
  end
end
