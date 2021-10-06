defmodule Printer.MixProject do
  use Mix.Project

  def project do
    [
      app: :printer,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Printer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_uart, "~> 1.3"},
      {:phoenix_pubsub, "~> 2.0"},
      {:nimble_options, "~> 0.3.0"},
      {:nimble_parsec, "~> 1.1"},
      {:erlport, "~> 0.10.1"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.5.0", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      lint: "credo --strict --all --config-file ../.credo.exs"
    ]
  end
end
