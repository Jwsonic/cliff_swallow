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

  # :disconnected status means it's ok to connect
  defp connect_precheck(%{status: :disconnected}, _opts), do: :ok

  # Otherwise we should check for the :override flag
  defp connect_precheck(%{connection: connection}, opts) do
    case Enum.find(opts, &Kernel.==(&1, :override)) do
      :override ->
        Connection.disconnect(connection)

        :ok

      _ ->
        :already_connected
    end
  end

  @impl GenServer
  def handle_call({:connect, connection, opts}, _from, state) do
    with :ok <- connect_precheck(state, opts),
         {:ok, connection} <- Connection.connect(connection) do
      state = State.update(state, %{connection: connection, status: :connected})

      {:reply, :ok, state}
    else
      {:error, _reason} = error ->
        state = State.update(state, %{status: :disconnected})

        {:reply, error, state}

      :already_connected ->
        {:reply, {:error, "Already connected"}, state}
    end
  end

  @impl GenServer
  def handle_call(:disconnect, _from, %{connection: connection} = state) do
    unless connection == nil do
      Connection.disconnect(connection)
    end

    state = State.update(state, %{connection: nil, status: :disconnected})

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl GenServer
  def handle_call({:print_start, _path}, _from, state) do
    {:reply, :ok, state}
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
