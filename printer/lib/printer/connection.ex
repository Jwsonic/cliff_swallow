defmodule Printer.Connection do
  @moduledoc """
  Internal API for managing a Connection
  """

  alias Printer.Connection.DynamicSupervisor, as: ConnectionSupervisor

  def open(connection, opts \\ []) do
    opts
    |> Keyword.merge(connection: connection)
    |> ConnectionSupervisor.start_connection_server()
  end

  def close(server) do
    GenServer.call(server, :close)
  end

  def send(server, message) do
    GenServer.call(server, {:send, message})
  end
end
