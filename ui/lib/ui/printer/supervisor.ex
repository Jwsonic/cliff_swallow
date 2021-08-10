defmodule Ui.Printer.Supervisor do
  use Supervisor

  alias Ui.Printer.PubSub
  alias Ui.Printer.Server, as: PrinterServer
  alias Ui.Printer.Config.Supervisor, as: ConfigSupervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      PubSub,
      ConfigSupervisor,
      PrinterServer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
