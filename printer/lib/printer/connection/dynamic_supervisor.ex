defmodule Printer.Connection.DynamicSupervisor do
  use DynamicSupervisor

  alias Printer.Connection.Server, as: ConnectionServer

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_connection_server(args \\ []) do
    spec = %{
      id: ConnectionServer,
      start: {ConnectionServer, :start_link, [args]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
