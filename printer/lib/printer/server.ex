defmodule Printer.Server do
  @moduledoc """
  GenServer responsible for keeping track of the current printer status.
  """
  use GenServer

  require Logger

  import Printer.Server.Logic

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    {:ok, build_initial_state(args)}
  end

  @impl GenServer
  def handle_call({:reset, args}, _from, _state) do
    {:reply, :ok, build_initial_state(args)}
  end

  @impl GenServer
  def handle_call({:connect, connection, override?}, _from, state) do
    with :ok <- connect_precheck(state, override?),
         {:ok, state} <- open_connection(state, connection) do
      {:reply, :ok, state}
    else
      {:error, reason, state} ->
        {:reply, {:error, reason}, state}

      :already_connected ->
        {:reply, {:error, "Already connected"}, state}
    end
  end

  @impl GenServer
  def handle_call(
        :disconnect,
        _from,
        state
      )
      when is_connected(state) do
    state = close_connection(state)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:disconnect, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:print_start, _path}, _from, state) do
    {:reply, :ok, state}
  end

  # We're waiting for a response to a prior message, so add this one to the queue
  @impl GenServer
  def handle_call(
        {:send, command},
        _from,
        state
      )
      when is_connected(state) and
             is_waiting(state) do
    state = add_to_send_queue(state, command)

    {:reply, :ok, state}
  end

  # The send queue is clear, so go ahead and send this message/wait
  @impl GenServer
  def handle_call({:send, command}, _from, state)
      when is_connected(state) do
    {reply, state} = send_command(state, command)

    {:reply, reply, state}
  end

  def handle_call({:send, _command}, _from, state) do
    {:reply, {:error, "Printer not connected", state}}
  end

  @impl GenServer
  def handle_info(
        {:connection_data, connection, data},
        state
      )
      when is_connected(state) and
             is_from_connection(state, connection) do
    Logger.info(data, label: :printer)

    with {:done, state} <- check_wait(state, data),
         {state, command} <- next_command(state) do
      {_reply, state} = send_command(state, command)

      {:noreply, state}
    else
      {:wait, state} ->
        {:noreply, state}

      {:no_commands, state} ->
        {:noreply, state}
    end
  end

  def handle_info({:connection_open, connection_server, _connection}, state)
      when is_connecting(state) do
    state = connected(state, connection_server)

    {:noreply, state}
  end

  def handle_info({:connection_open, _connection_server, connection}, state) do
    Logger.warn(
      "Got :connection_open for #{inspect(connection.__struct__)} message but status was: #{state.status}"
    )

    {:noreply, state}
  end

  def handle_info(
        {:connection_open_failed, _connection, error},
        state
      )
      when is_connecting(state) do
    Logger.warn("Connection open failed with error #{error}")

    state = close_connection(state)

    {:noreply, state}
  end

  def handle_info(
        {:connection_open_failed, connection, _error},
        state
      ) do
    Logger.warn(
      "Got :connection_open_failed for #{inspect(connection.__struct__)} message but status was: #{state.status}"
    )

    {:noreply, state}
  end

  def handle_info({:send_timeout, reference}, state) do
    state =
      with :retry <- check_timeout(state, reference),
           {:ok, state} <- retry_send_command(state) do
        state
      else
        :ignore ->
          state

        {:error, error} ->
          Logger.error(error)
          Logger.info("Closing connection due to retry failure.")

          close_connection(state)
      end

    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.warn("Unhandled message: #{inspect(message)}")
    {:noreply, state}
  end
end
