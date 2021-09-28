defmodule Printer.Server do
  @moduledoc """
  GenServer responsible for keeping track of the current printer status.
  """
  use GenServer

  require Logger

  defmodule State do
    @moduledoc """
    State struct for `Printer.Server`.
    """
    defstruct [:connection, :status]
  end

  alias Printer.Connection
  alias Printer.Server.State

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    state = %State{
      connection: nil,
      status: :disconnected
    }

    {:ok, state}
  end

  # override? -> true means always connect and maybe disconnect too
  defp connect_precheck(%State{connection: connection}, true) do
    if is_pid(connection) do
      Connection.close(connection)
    end

    :ok
  end

  # :disconnected status means it's ok to connect
  defp connect_precheck(%State{status: :disconnected}, _override?), do: :ok

  # Otherwise its an error
  defp connect_precheck(_state, _override?), do: :already_connected

  @impl GenServer
  def handle_call({:connect, connection, override?}, _from, state) do
    with :ok <- connect_precheck(state, override?),
         {:ok, _connection} <- Connection.open(connection) do
      state = %{state | connection: nil, status: :connecting}

      {:reply, :ok, state}
    else
      {:error, _reason} = error ->
        state = %{state | connection: nil, status: :disconnected}

        {:reply, error, state}

      :already_connected ->
        {:reply, {:error, "Already connected"}, state}
    end
  end

  @impl GenServer
  def handle_call(
        :disconnect,
        _from,
        %State{connection: connection} = state
      ) do
    if is_pid(connection) && Process.alive?(connection) do
      Connection.close(connection)
    end

    state = %{state | connection: nil, status: :disconnected}

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:print_start, _path}, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(
        {:send, command},
        _from,
        %State{connection: connection, status: :connected} = state
      ) do
    reply = Connection.send(connection, command)

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info(
        {:connection_data, connection, data},
        %{connection: connection} = state
      )
      when not is_nil(connection) do
    Logger.info(data, label: :printer)

    {:noreply, state}
  end

  def handle_info(
        {:connection_open, connection, _connection},
        %{status: :connecting} = state
      ) do
    state = %{
      state
      | connection: connection,
        status: :connected
    }

    {:noreply, state}
  end

  def handle_info(
        {:connection_open_failed, _connection, error},
        %{status: :connecting} = state
      ) do
    Logger.warn("Connection open failed with error #{error}")

    state = %{
      state
      | connection: nil,
        status: :disconnected
    }

    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.warn("Unhandled message: #{inspect(message)}")
    {:noreply, state}
  end
end
