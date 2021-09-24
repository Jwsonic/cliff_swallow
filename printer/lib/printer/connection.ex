defmodule Printer.Connection do
  @moduledoc """
  Internal API for managing a Connection
  """

  alias Printer.Connection.DynamicSupervisor, as: ConnectionSupervisor

  def open(connection, printer_server \\ nil) do
    args = [
      connection: connection,
      printer_server: printer_server || self()
    ]

    ConnectionSupervisor.start_connection_server(args)
  end

  def close(server) when is_pid(server) do
    GenServer.call(server, :close)
  end

  def send(server, message) when is_pid(server) do
    GenServer.call(server, {:send, message})
  end
end
