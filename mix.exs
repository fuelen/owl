defmodule Owl.MixProject do
  use Mix.Project

  def project do
    [
      app: :owl,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [ignore_modules: [Owl.Palette]],
      name: "Owl"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Owl.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
