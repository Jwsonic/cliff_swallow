defmodule Ui.Printer.Connection.Virtual.Server do
  @moduledoc """
  Manages a 'virtual' printer from Octoprint.
  """
  use GenServer

  alias Ui.Printer.Connection.Virtual.Logic

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    state = Logic.init(args)

    {:ok, state, {:continue, :start_port}}
  end

  def handle_continue(:start_port, state) do
    updated_state = Logic.start_port(state)

    {:noreply, updated_state}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    Logic.port_data(state, data)

    {:noreply, state}
  end

  def handle_info(
        {:DOWN, reference, :port, port, reason},
        %{reference: reference, port: port} = state
      ) do
    Logic.port_closed(state, reason)

    {:stop, reason, state}
  end

  # Drop other messages for now
  def handle_info(_message, state) do
    {:noreply, state}
  end

  def send(command) do
    GenServer.call(__MODULE__, {:send, command})
  end

  def handle_call({:send, command}, _from, state) do
    reply = Logic.send(state, command)

    {:reply, reply, state}
  end
end
