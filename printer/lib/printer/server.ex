defmodule Printer.Server do
  @moduledoc """
  GenServer responsible for keeping track of the current printer status.
  """
  use GenServer

  require Logger

  alias Printer.{Connection, State}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    state = State.new()

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:connect, connection}, _from, %State{connection: nil} = state) do
    case Connection.connect(connection) do
      {:ok, connection} -> {:reply, :ok, %{state | connection: connection, status: :connected}}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:connection, _connection}, _from, state) do
    {:reply, {:error, "Already connected"}, state}
  end

  @impl GenServer
  def handle_call({:send, command}, _from, %State{connection: connection} = state) do
    reply = Connection.send(connection, command)

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info({:connection_data, data}, state) do
    Logger.info(data, label: :printer)

    {:noreply, state}
  end

  def handle_info(message, %State{connection: connection} = state) do
    case Connection.update(connection, message) do
      {:ok, connection} -> {:noreply, %{state | connection: connection}}
      {:error, reason} -> {:stop, reason, connection}
    end
  end
end
