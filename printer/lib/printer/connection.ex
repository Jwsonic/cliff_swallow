defmodule Printer.Connection do
  @moduledoc """
  Internal API for managing a Connection
  """

  use Norms

  alias Printer.Connection.DynamicSupervisor, as: ConnectionSupervisor

  def open(connection, opts \\ []) do
    opts
    |> Keyword.merge(connection: connection)
    |> ConnectionSupervisor.start_connection_server()
  end

  def close(connection) do
    GenServer.call(connection, :close)
  end

  def send(connection, message) do
    GenServer.call(connection, {:send, message})
  end
end
