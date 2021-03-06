defmodule Printer.Connection do
  @moduledoc """
  Internal API for managing a Connection
  """

  alias Printer.Connection.DynamicSupervisor, as: ConnectionSupervisor

  def available do
    Circuits.UART.enumerate()
    |> Enum.reject(fn {_name, c} -> c == %{} end)
    |> Enum.map(fn {name, _data} ->
      %{
        name: name,
        build: fn ->
          Printer.Connection.Serial.new(name: name, speed: 250_000)
        end
      }
    end)
  end

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

  def close(_server), do: :ok

  def send(server, message) when is_pid(server) do
    GenServer.call(server, {:send, message})
  end

  def send(_server, _message), do: :ok
end
