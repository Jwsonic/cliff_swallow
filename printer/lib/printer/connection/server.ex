defmodule Printer.Connection.Server do
  @moduledoc """
  GenServer for handling connections and their various lifecycle events.
  """
  use GenServer

  require Logger

  defmodule State do
    @moduledoc """
    State struct for Connection Server
    """
    defstruct [:connection, :printer_server]
  end

  alias Printer.Connection.Protocol, as: ConnectionProtocol
  alias Printer.Connection.Server.State

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    state = %State{
      connection: Keyword.fetch!(args, :connection),
      printer_server: Keyword.fetch!(args, :printer_server)
    }

    {:ok, state, {:continue, :open_connection}}
  end

  @impl GenServer
  def handle_continue(:open_connection, %State{connection: connection} = state) do
    case ConnectionProtocol.open(connection) do
      {:ok, connection} ->
        state = %{state | connection: connection}

        send_to_printer(state, :connection_open, connection)

        {:noreply, state}

      {:error, reason} ->
        send_to_printer(state, :connection_open_failed, reason)

        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_call(:close, _from, %State{connection: connection} = state) do
    reply = ConnectionProtocol.close(connection)

    {:stop, :normal, reply, state}
  end

  @impl GenServer
  def handle_call({:send, message}, _from, %State{connection: connection} = state) do
    reply = ConnectionProtocol.send(connection, message)

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info(message, %State{connection: connection} = state) do
    # The message may not be for the protocol, so catch function clause errors here
    response =
      try do
        ConnectionProtocol.handle_message(connection, message)
      rescue
        FunctionClauseError ->
          Logger.info("handle_message/2 unable to handle message: #{inspect(message)}")

          :ok
      end

    case response do
      {:ok, connection} ->
        {:noreply, %{state | connection: connection}}

      {:ok, connection, response} ->
        state = %{state | connection: connection}

        send_to_printer(state, :connection_response, response)

        {:noreply, state}

      {:closed, reason} ->
        send_to_printer(state, :connection_closed, reason)

        {:stop, :normal, reason, state}

      {:error, error, connection} ->
        state = %{state | connection: connection}

        send_to_printer(state, :connection_error, error)

        {:noreply, state}
    end
  end

  defp send_to_printer(%State{printer_server: printer_server}, type, data \\ nil) do
    message =
      case data do
        nil -> {type, self()}
        data -> {type, self(), data}
      end

    Process.send(printer_server, message, [])
  end
end
