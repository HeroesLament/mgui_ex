defmodule MguiEx do
  @moduledoc """
  mgui_ex — Build native macOS menu bar apps in Elixir.

  ## Scene-based usage (recommended)

      defmodule MyApp.MainScene do
        use MguiEx.Scene
        import MguiEx.View

        def init(_opts), do: %{count: 0}

        def render(state) do
          vstack([spacing: 12], [
            text("Count: \#{state.count}") |> font("title"),
            button("Increment", id: "btn-inc")
          ]) |> pad(16)
        end

        def handle_event("btn-inc", "tap", state) do
          %{state | count: state.count + 1}
        end

        def handle_event(_, _, state), do: state

        def status_bar(_state) do
          [title: "MyApp", icon: "star.fill"]
        end
      end

      # Start everything:
      MguiEx.SwiftPort.start_link()
      MguiEx.SceneManager.start_link(scenes: [MyApp.MainScene])

  ## Direct usage (no scenes)

      MguiEx.SwiftPort.start_link()
      import MguiEx.View
      MguiEx.render(text("Hello") |> pad(16), title: "Hi", icon: "star.fill")
  """

  defdelegate render(tree, opts \\ []), to: MguiEx.SwiftPort
  defdelegate activate(scene), to: MguiEx.SceneManager
end
