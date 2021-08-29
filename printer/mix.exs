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
      {:norms,
       git: "https://github.com/Jwsonic/norms", ref: "96d0ec2b5492de0eaa8b6ce7afc1c37a46bfba48"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.5.0", only: :test}
    ]
  end

  defp aliases do
    [
      lint: "credo --strict --all --config-file ../.credo.exs"
    ]
  end
end
