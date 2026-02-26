defmodule MguiEx.View do
  @moduledoc """
  Builder functions for constructing view trees with modifiers.

  ## Usage

      import MguiEx.View

      vstack([spacing: 12], [
        text("Hello!", font: "headline"),
        text_field("Username", id: "tf-user", placeholder: "Enter username"),
        secure_field("Password", id: "tf-pass", placeholder: "Enter password"),
        toggle("Remember me", id: "tgl-remember", isOn: true),
        picker("Realm", id: "pk-realm",
          selection: "CORP",
          options: [{"CORP", "CORP.EXAMPLE.COM"}, {"DEV", "DEV.EXAMPLE.COM"}]),
        button("Sign In", id: "btn-signin") |> bg("accentColor") |> fg("white") |> rounded(8)
      ])
      |> pad(16)
  """

  # -------------------------------------------------------------------
  # Layout
  # -------------------------------------------------------------------

  def vstack(opts \\ [], children) when is_list(children), do: node("VStack", opts, children)
  def hstack(opts \\ [], children) when is_list(children), do: node("HStack", opts, children)
  def zstack(opts \\ [], children) when is_list(children), do: node("ZStack", opts, children)
  def spacer(opts \\ []), do: leaf("Spacer", opts)
  def divider(opts \\ []), do: leaf("Divider", opts)

  # -------------------------------------------------------------------
  # Content
  # -------------------------------------------------------------------

  def text(content, opts \\ []) do
    leaf("Text", Keyword.put(opts, :content, content))
  end

  def image(system_name, opts \\ []) do
    leaf("Image", Keyword.put(opts, :systemName, system_name))
  end

  def label(content, system_name, opts \\ []) do
    opts
    |> Keyword.put(:content, content)
    |> Keyword.put(:systemName, system_name)
    |> then(&leaf("Label", &1))
  end

  def link(content, url, opts \\ []) do
    opts
    |> Keyword.put(:content, content)
    |> Keyword.put(:url, url)
    |> then(&leaf("Link", &1))
  end

  def progress_view(opts \\ []), do: leaf("ProgressView", opts)

  # -------------------------------------------------------------------
  # Input controls
  # -------------------------------------------------------------------

  @doc "Tappable button with text label"
  def button(label_text, opts \\ []) do
    leaf("Button", Keyword.put(opts, :label, label_text))
  end

  @doc "Button with custom child content"
  def button_with(opts \\ [], children) when is_list(children) do
    node("Button", opts, children)
  end

  @doc """
  Text input field. Sends `change:<value>` on every keystroke and `submit:<value>` on Enter.

  ## Options
    * `:placeholder` - placeholder text
    * `:text` - initial text value
    * `:style` - "plain" | "roundedBorder" (default)
  """
  def text_field(placeholder, opts \\ []) do
    opts = Keyword.put_new(opts, :placeholder, placeholder)
    leaf("TextField", opts)
  end

  @doc """
  Password input field. Same events as text_field but text is masked.
  """
  def secure_field(placeholder, opts \\ []) do
    opts = Keyword.put_new(opts, :placeholder, placeholder)
    leaf("SecureField", opts)
  end

  @doc """
  Boolean toggle switch. Sends `change:true` or `change:false`.

  ## Options
    * `:isOn` - initial state (default false)
  """
  def toggle(label_text, opts \\ []) do
    leaf("Toggle", Keyword.put(opts, :label, label_text))
  end

  @doc """
  Dropdown/segmented picker. Sends `change:<value>` with the selected option value.

  ## Options
    * `:selection` - initially selected value
    * `:options` - list of `{value, label}` tuples
    * `:pickerStyle` - "menu" (default) | "segmented" | "inline" | "radioGroup"

  ## Example

      picker("Realm", id: "pk-realm",
        selection: "CORP",
        options: [{"CORP", "CORP.EXAMPLE.COM"}, {"DEV", "DEV.EXAMPLE.COM"}],
        pickerStyle: "segmented")
  """
  def picker(label_text, opts \\ []) do
    {raw_options, opts} = Keyword.pop(opts, :options, [])

    options =
      Enum.map(raw_options, fn
        {value, label} -> %{"value" => value, "label" => label}
        %{} = m -> m
      end)

    opts
    |> Keyword.put(:label, label_text)
    |> Keyword.put(:options, options)
    |> then(&leaf("Picker", &1))
  end

  # -------------------------------------------------------------------
  # Containers
  # -------------------------------------------------------------------

  @doc """
  Scrollable container. Default axis: vertical.

  ## Options
    * `:axes` - "vertical" (default) | "horizontal" | "both"
    * `:showsIndicators` - true (default) | false
  """
  def scroll_view(opts \\ [], children) when is_list(children) do
    node("ScrollView", opts, children)
  end

  @doc "Native list view"
  def list(opts \\ [], children) when is_list(children) do
    node("List", opts, children)
  end

  @doc """
  Form container (settings-style layout).

  ## Options
    * `:formStyle` - "grouped" (default) | "columns"
  """
  def form(opts \\ [], children) when is_list(children) do
    node("Form", opts, children)
  end

  @doc """
  Section with optional header/footer text.

  ## Options
    * `:header` - header text
    * `:footer` - footer text
  """
  def section(opts \\ [], children) when is_list(children) do
    node("Section", opts, children)
  end

  @doc "Grouping container (no visual effect, useful for applying modifiers to a set)"
  def group(opts \\ [], children) when is_list(children) do
    node("Group", opts, children)
  end

  # -------------------------------------------------------------------
  # Menu builder (for right-click context menu)
  # -------------------------------------------------------------------

  @doc """
  Build a menu item for the right-click context menu.

  ## Examples

      menu_item("Preferences...", id: "menu-prefs", shortcut: "cmd+,", icon: "gearshape")
      menu_item("Quit", id: "menu-quit", shortcut: "cmd+q")
      menu_divider()
  """
  def menu_item(title, opts \\ []) do
    id = Keyword.get(opts, :id, title)

    %{
      "id" => id,
      "title" => title,
      "icon" => Keyword.get(opts, :icon),
      "shortcut" => Keyword.get(opts, :shortcut),
      "enabled" => Keyword.get(opts, :enabled, true),
      "state" => Keyword.get(opts, :state),
      "divider" => false,
      "children" => Keyword.get(opts, :children)
    }
  end

  @doc "Menu separator line"
  def menu_divider do
    %{"id" => "_divider", "divider" => true}
  end

  @doc "Submenu with children"
  def submenu(title, children, opts \\ []) when is_list(children) do
    menu_item(title, Keyword.put(opts, :children, children))
  end

  # -------------------------------------------------------------------
  # Modifier pipeline
  # -------------------------------------------------------------------

  def modifier(view, type, args \\ [])

  def modifier(%{"modifiers" => existing} = view, type, args) do
    mod = build_modifier(type, args)
    %{view | "modifiers" => (existing || []) ++ [mod]}
  end

  def modifier(view, type, args) when is_map(view) do
    mod = build_modifier(type, args)
    Map.put(view, "modifiers", [mod])
  end

  # -------------------------------------------------------------------
  # Convenience modifier shorthands
  # -------------------------------------------------------------------

  def pad(view, value) when is_number(value), do: modifier(view, :padding, value: value)
  def pad(view, edges) when is_list(edges), do: modifier(view, :padding, edges)

  def frame(view, opts), do: modifier(view, :frame, opts)

  def font(view, name) when is_binary(name), do: modifier(view, :font, fontName: name)
  def font(view, opts) when is_list(opts), do: modifier(view, :font, opts)

  def fg(view, color), do: modifier(view, :foregroundColor, color: color)
  def bg(view, color), do: modifier(view, :background, color: color)
  def rounded(view, radius), do: modifier(view, :cornerRadius, value: radius)
  def opacity(view, value), do: modifier(view, :opacity, opacity: value)
  def shadow(view, opts \\ []), do: modifier(view, :shadow, opts)
  def border(view, color, width \\ 1), do: modifier(view, :border, borderColor: color, borderWidth: width)

  # -------------------------------------------------------------------
  # Internal helpers
  # -------------------------------------------------------------------

  @counter_key :mgui_ex_node_counter

  defp next_id(prefix) do
    count = Process.get(@counter_key, 0)
    Process.put(@counter_key, count + 1)
    "#{prefix}.#{count}"
  end

  @doc false
  def reset_ids, do: Process.put(@counter_key, 0)

  defp node(type, opts, children) do
    id = Keyword.get(opts, :id) || next_id(type)
    props = opts |> Keyword.drop([:id]) |> props_map()

    %{
      "id" => id,
      "type" => type,
      "props" => props,
      "children" => children,
      "modifiers" => nil
    }
  end

  defp leaf(type, opts), do: node(type, opts, nil)

  defp props_map(opts) do
    opts
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  end

  defp build_modifier(type, args) do
    %{
      "type" => to_string(type),
      "args" => args |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }
  end
end
