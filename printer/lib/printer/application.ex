defmodule Printer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Printer.PubSub,
      Printer.Server
    ]

    opts = [strategy: :one_for_one, name: Printer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
