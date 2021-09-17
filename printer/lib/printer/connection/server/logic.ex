defmodule Printer.Connection.Server.Logic do
  alias Printer.Connection.Server.State
  alias Printer.Connection.Protocol, as: ConnectionProtocol

  defp send_to_printer(%State{printer_server: printer_server}, message) do
    Process.send(printer_server, message, [])
  end

  def init(args) do
    State.new(args)
  end

  def close(%State{connection: connection}) do
    case connection do
      nil -> :ok
      _ -> ConnectionProtocol.close(connection)
    end
  end

  def send(%State{connection: nil}, _messsage) do
    {:error, "Not connected"}
  end

  def send(%State{connection: connection}, message) do
    ConnectionProtocol.send(connection, message)
  end

  def open_connection(%State{connection: connection} = state) do
    case ConnectionProtocol.open(connection) do
      {:ok, connection} ->
        send_to_printer(state, {:connection_open, self()})

        {:ok, %{state | connection: connection}}

      {:error, reason} = error ->
        send_to_printer(state, {:connection_open_failed, self(), reason})

        error
    end
  end

  def handle_response(%State{connection: connection} = state, message) do
    case ConnectionProtocol.handle_response(connection, message) do
      :ok ->
        state

      :closed ->
        send_to_printer(state, :connection_closed)

        %{state | connection: nil}

      {:ok, response} ->
        send_to_printer(state, {:connection_response, response})

        state

      {:error, error} ->
        send_to_printer(state, {:connection_error, error})

        state
    end
  end
end
