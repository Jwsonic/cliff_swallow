defmodule Printer.Connection.Server.Logic do
  alias Printer.Connection.Server.State
  alias Printer.Connection.Protocol, as: ConnectionProtocol

  defp send_to_printer(%State{printer_server: printer_server}, message) do
    Process.send(printer_server, message, [])
  end

  def init(args) do
    args
    |> Keyword.get(:printer_server)
    |> Kernel.||(Printer.Server)
    |> State.new()
  end

  # no connection? good to go
  def connect_precheck(%State{connection: nil}, _override?), do: :ok

  # existing connections need to be closed
  def connect_precheck(%State{connection: connection}, true) do
    ConnectionProtocol.close(connection)
  end

  # otherwise we're already happily connected
  def connect_precheck(_state, _override?), do: {:error, "Already connected"}

  def close(%State{connection: connection} = state) do
    reply =
      case connection do
        nil -> :ok
        _ -> ConnectionProtocol.close(connection)
      end

    state = State.update(state, %{connection: nil})

    {reply, state}
  end

  def send(%State{connection: nil}, _messsage) do
    {:error, "Not connected"}
  end

  def send(%State{connection: connection}, message) do
    ConnectionProtocol.send(connection, message)
  end

  def open_connection(state, connection) do
    case ConnectionProtocol.open(connection) do
      {:ok, connection} ->
        send_to_printer(state, {:connection_open, self()})

        State.update(state, %{connection: connection})

      {:error, reason} ->
        send_to_printer(state, {:connection_open_failed, self(), reason})

        State.update(state, %{connection: nil})
    end
  end

  def handle_response(%State{connection: connection} = state, message) do
    case ConnectionProtocol.handle_response(connection, message) do
      :ok ->
        state

      :closed ->
        send_to_printer(state, :connection_closed)

        State.update(state, %{connection: nil})

      {:ok, response} ->
        send_to_printer(state, {:connection_response, response})

        state

      {:error, error} ->
        send_to_printer(state, {:connection_error, error})

        state
    end
  end
end
