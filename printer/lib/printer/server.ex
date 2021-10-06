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
  def handle_call({:print_start, path}, _from, state) do
    case start_print(state, path) do
      {:ok, state} ->
        {:reply, :ok, state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:print_stop, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:send, command}, _from, state) do
    with :ok <- send_precheck(state, command) |> IO.inspect(label: :precheck) do
      {reply, state} = send_command(state, command)
      {:reply, reply, state}
    else
      :wating ->
        state = add_to_send_queue(state, command)
        {:reply, :ok, state}

      reply ->
        {:reply, reply, state}
    end
  end

  @impl GenServer

  def handle_info(
        {:connection_data, connection, data},
        state
      )
      when (is_connected(state) or is_printing(state)) and
             is_from_connection(state, connection) do
    Logger.info(data, label: :printer)

    state =
      case process_response(state, data) do
        {:ignore, state} ->
          state

        {:send_next, state} ->
          send_next(state)

        {:resend, command, state} ->
          resend_command(state, command)
      end

    {:noreply, state}
  end

  def handle_info(
        {:connection_data, _connection, data},
        state
      ) do
    Logger.info("Not printer #{data}")

    {:noreply, state}
  end

  def handle_info(
        {
          :connection_open,
          connection_server,
          _connection
        },
        state
      )
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

  def handle_info(message, state) do
    Logger.warn("Unhandled message: #{inspect(message)}")
    {:noreply, state}
  end
end
