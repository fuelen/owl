defmodule Owl.MixProject do
  use Mix.Project
  @version "0.1.0"
  @source_url "https://github.com/fuelen/owl"

  def project do
    [
      app: :owl,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [ignore_modules: [Owl.Palette]],
      package: package(),
      docs: docs(),
      name: "Owl"
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [{:"README.md", [title: "README"]}]
    ]
  end

  defp package do
    [
      description: "A toolkit for writing command-line user interfaces.",
      licenses: ["Apache-2.0"],
      links: %{
        GitHub: @source_url
      }
    ]
  end

  def application do
    [
      mod: {Owl.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
