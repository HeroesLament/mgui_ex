defmodule MguiEx.MixProject do
  use Mix.Project

  @version "0.1.3"
  @source_url "https://github.com/HeroesLament/mgui_ex"

  def project do
    [
      app: :mgui_ex,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "MguiEx",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:msgpax, "~> 2.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "SwiftUI menu bar applications driven from Elixir via a msgpack Port protocol. Render native macOS status bar popovers with a declarative view tree."
  end

  defp package do
    [
      files: ~w(lib swift mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "MguiEx",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
