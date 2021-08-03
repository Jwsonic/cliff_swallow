defmodule Ui.Printer.Virtual.Supervisor do
  use DynamicSupervisor

  alias Ui.Printer.Virtual.Server, as: VirtualServer

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_virtual_printer(args \\ []) do
    DynamicSupervisor.start_child(__MODULE__, {VirtualServer, args})
  end
end
