defmodule Printer.Connection.Server do
  @moduledoc """
  GenServer for handling connections and their various lifecycle events.
  """
  use GenServer

  alias Printer.Connection.Server.Logic
  alias Printer.Connection.Server.State

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    state = Logic.init(args)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:open, connection, override?}, _from, state) do
    case Logic.connect_precheck(state, override?) do
      :ok ->
        {:reply, :ok, state, {:continue, {:open_connection, connection}}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:close, _from, state) do
    {reply, state} = Logic.close(state)

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:send, message}, _from, state) do
    reply = Logic.send(state, message)

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_continue({:open_connection, connection}, state) do
    state = Logic.open_connection(state, connection)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_message, %State{connection: nil} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(message, state) do
    state = Logic.handle_response(state, message)

    {:noreply, state}
  end
end
