defmodule Printer.Connection.Server do
  @moduledoc """
  GenServer for handling connections and their various lifecycle events.
  """
  use GenServer

  alias Printer.Connection.Server.Logic

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    state = Logic.init(args)

    {:ok, state, {:continue, :open_connection}}
  end

  @impl GenServer
  def handle_continue(:open_connection, state) do
    case Logic.open_connection(state) do
      {:ok, state} -> {:noreply, state}
      {:error, _error} -> {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_call(:close, _from, state) do
    reply = Logic.close(state)

    {:stop, :normal, reply, state}
  end

  @impl GenServer
  def handle_call({:send, message}, _from, state) do
    reply = Logic.send(state, message)

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info(message, state) do
    state = Logic.handle_response(state, message)

    {:noreply, state}
  end
end
