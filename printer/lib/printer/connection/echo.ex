defmodule Printer.Connection.Echo do
  @moduledoc """
  A Printer Connection that stores commands in an Agent.
  """
  defstruct [:listener]

  def new do
    listener = self()

    %__MODULE__{
      listener: listener
    }
  end

  defimpl Printer.Connection.Protocol, for: Printer.Connection.Echo do
    alias Printer.Connection.Echo

    def open(%Echo{} = connection) do
      send_echo(connection, :open)

      {:ok, connection}
    end

    def close(%Echo{} = connection) do
      send_echo(connection, :close)
    end

    def send(%Echo{} = connection, message) do
      send_echo(connection, {:send, message})
    end

    def handle_response(%Echo{} = connection, response) do
      send_echo(connection, {:handle_response, response})

      response
    end

    defp send_echo(%Echo{listener: listener}, message) do
      Process.send(listener, {Echo, message}, [])
    end
  end
end
