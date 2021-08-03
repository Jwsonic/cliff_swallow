defmodule Ui.Printer.Supervisor do
  use Supervisor

  alias Ui.Printer.Virtual.Supervisor, as: VirtualSupervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      VirtualSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
