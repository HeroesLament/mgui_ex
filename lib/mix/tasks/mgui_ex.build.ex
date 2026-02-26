defmodule Mix.Tasks.MguiEx.Build do
  @moduledoc """
  Builds the MguiExRuntime Swift binary and wraps it in a .app bundle.

  ## Usage

      mix mgui_ex.build            # debug build
      mix mgui_ex.build --release  # release (optimized) build

  ## What it does

  1. Runs `swift build` in the `swift/` directory
  2. Creates a `.app` bundle with a proper Info.plist
  3. Symlinks (debug) or copies (release) the binary into the bundle

  The .app bundle is required for macOS features that need a bundle identity:
  - UNUserNotificationCenter (push notifications with actions/dismiss callbacks)
  - SMAppService (launch at login)
  - UserDefaults suite names
  - Proper Dock/menu bar behavior

  The bundle is created at `swift/.build/MguiExRuntime.app/`.
  """

  use Mix.Task

  @app_name "MguiExRuntime"
  @bundle_id "com.mgui_ex.runtime"

  @impl Mix.Task
  def run(args) do
    release? = "--release" in args
    swift_dir = Path.join(File.cwd!(), "swift")

    # Step 1: Build Swift
    config = if release?, do: "-c release", else: ""
    Mix.shell().info("Building Swift (#{if release?, do: "release", else: "debug"})...")

    {output, status} = System.cmd("swift", ["build"] ++ String.split(config),
      cd: swift_dir,
      stderr_to_stdout: true
    )

    if status != 0 do
      Mix.shell().error(output)
      Mix.raise("swift build failed with status #{status}")
    end

    Mix.shell().info("Swift build succeeded.")

    # Step 2: Locate the binary
    build_config = if release?, do: "release", else: "debug"
    binary_path = Path.join([swift_dir, ".build", "arm64-apple-macosx", build_config, @app_name])

    unless File.exists?(binary_path) do
      Mix.raise("Binary not found at #{binary_path}")
    end

    # Step 3: Create .app bundle
    app_dir = Path.join([swift_dir, ".build", "#{@app_name}.app"])
    contents_dir = Path.join(app_dir, "Contents")
    macos_dir = Path.join(contents_dir, "MacOS")

    File.rm_rf!(app_dir)
    File.mkdir_p!(macos_dir)

    # Info.plist
    bundle_id = Application.get_env(:mgui_ex, :bundle_id, @bundle_id)
    app_name = Application.get_env(:mgui_ex, :app_name, @app_name)

    info_plist = info_plist(bundle_id, app_name)
    File.write!(Path.join(contents_dir, "Info.plist"), info_plist)

    # Binary: hardlink for dev (fast, no copy, but macOS sees it as in-bundle),
    # copy for release (standalone)
    dest_binary = Path.join(macos_dir, @app_name)

    if release? do
      File.cp!(binary_path, dest_binary)
    else
      # Hardlink: macOS resolves bundle identity from the path, not the inode.
      # A symlink resolves to outside the bundle; a hardlink stays "in" it.
      {_, 0} = System.cmd("ln", [binary_path, dest_binary])
    end

    Mix.shell().info("App bundle created: #{app_dir}")

    # Step 4: For release, also copy to priv/
    if release? do
      priv_dir = Path.join(File.cwd!(), "priv")
      priv_app = Path.join(priv_dir, "#{@app_name}.app")
      File.rm_rf!(priv_app)
      File.mkdir_p!(priv_dir)
      # Copy entire .app bundle
      {_, 0} = System.cmd("cp", ["-R", app_dir, priv_app])
      Mix.shell().info("Release bundle copied to: #{priv_app}")
    end

    :ok
  end

  defp info_plist(bundle_id, app_name) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleIdentifier</key>
        <string>#{bundle_id}</string>

        <key>CFBundleName</key>
        <string>#{app_name}</string>

        <key>CFBundleDisplayName</key>
        <string>#{app_name}</string>

        <key>CFBundleExecutable</key>
        <string>#{@app_name}</string>

        <key>CFBundlePackageType</key>
        <string>APPL</string>

        <key>CFBundleVersion</key>
        <string>1.0</string>

        <key>CFBundleShortVersionString</key>
        <string>1.0</string>

        <key>LSMinimumSystemVersion</key>
        <string>14.0</string>

        <key>LSUIElement</key>
        <true/>

        <key>NSUserNotificationAlertStyle</key>
        <string>alert</string>
    </dict>
    </plist>
    """
  end
end
