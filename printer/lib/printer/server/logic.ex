defmodule Printer.Server.Logic do
  @moduledoc """
  Business logic functions/gaurds/macros to help make the server a bit more readable.
  """

  alias Printer.Connection
  alias Printer.Server.{State, Wait}

  defguard is_state(state) when is_struct(state, State)

  defguard is_connecting(state) when is_state(state) and state.status == :connecting

  defguard is_connected(state)
           when is_state(state) and
                  state.status == :connected and
                  is_pid(state.connection_server)

  defguard is_waiting(state) when is_state(state) and state.wait != nil

  defguard is_from_connection(state, connection_server)
           when is_state(state) and is_pid(connection_server) and
                  state.connection_server == connection_server

  def build_initial_state(_args \\ []) do
    %State{
      connection_server: nil,
      retry_count: 0,
      send_queue: :queue.new(),
      status: :disconnected,
      timeout_reference: nil,
      wait: nil
    }
  end

  # override? -> true means always connect and maybe disconnect too
  @spec connect_precheck(state :: State.t(), override? :: boolean()) :: :ok
  def connect_precheck(%State{connection_server: connection_server}, true) do
    if is_pid(connection_server) do
      Connection.close(connection_server)
    end

    :ok
  end

  # :disconnected status means it's ok to connect
  def connect_precheck(%State{status: :disconnected}, _override?), do: :ok

  # Otherwise its an error
  def connect_precheck(_state, _override?), do: :already_connected

  @spec open_connection(state :: State.t(), connection :: any()) ::
          {:ok, state :: State.t()}
          | {:error, reason :: String.t(), state :: State.t()}
  def open_connection(%State{} = state, connection) do
    case Connection.open(connection) do
      {:ok, _connection} ->
        state = %{
          state
          | connection_server: nil,
            status: :connecting
        }

        {:ok, state}

      {:error, reason} ->
        state = %{
          state
          | connection_server: nil,
            status: :disconnected
        }

        {:error, reason, state}
    end
  end

  @spec connected(state :: State.t(), connection_server :: pid()) :: State.t()
  def connected(%State{} = state, connection_server) do
    %{
      state
      | connection_server: connection_server,
        status: :connected
    }
  end

  @spec close_connection(state :: State.t()) :: State.t()
  def close_connection(%State{connection_server: connection_server}) do
    if is_pid(connection_server) && Process.alive?(connection_server) do
      Connection.close(connection_server)
    end

    build_initial_state()
  end

  @spec send_command(state :: State.t(), command :: String.t()) ::
          {reply :: any(), state :: State.t()}
  def send_command(%State{} = state, command) do
    reply = Connection.send(state.connection_server, command)
    wait = Wait.build(command)
    timeout_reference = Wait.schedule_timeout(wait)

    state = %{
      state
      | timeout_reference: timeout_reference,
        wait: wait
    }

    {reply, state}
  end

  @spec add_to_send_queue(state :: State.t(), command :: String.t()) :: State.t()
  def add_to_send_queue(%State{send_queue: send_queue} = state, command) do
    %{
      state
      | send_queue: :queue.in(command, send_queue)
    }
  end

  @max_retry_count 5

  @spec retry_send_command(state :: State.t()) :: {:ok, State.t()} | {:error, String.t()}
  def retry_send_command(%State{} = state) do
    retry_count = state.retry_count + 1
    command = state.wait.command

    case retry_count > @max_retry_count do
      true ->
        {:error, "Over max retry count for #{command}"}

      false ->
        {_reply, state} = send_command(state, command)

        state = %{state | retry_count: retry_count}

        {:ok, state}
    end
  end

  @spec check_wait(state :: State.t(), response :: String.t()) ::
          {:wait, state :: State.t()} | {:done, State.t()}
  def check_wait(%State{wait: wait} = state, response) do
    case Wait.check(wait, response) do
      :done ->
        {:done, %{state | timeout_reference: nil, wait: nil}}

      {:wait, wait} ->
        {:wait, %{state | wait: wait}}
    end
  end

  @spec check_timeout(state :: State.t(), reference :: reference()) ::
          :ignore | :retry
  def check_timeout(
        %State{
          timeout_reference: timeout_reference,
          wait: %Wait{}
        },
        timeout_reference
      ) do
    :retry
  end

  def check_timeout(_state, _reference), do: :ignore

  @spec next_command(state :: State.t()) ::
          {:no_commands, state :: :State.t()} | {state :: State.t(), command :: String.t()}
  def next_command(%State{send_queue: send_queue} = state) do
    case :queue.out(send_queue) do
      {:empty, _send_queue} -> {:no_commands, state}
      {{:value, command}, send_queue} -> {%{state | send_queue: send_queue}, command}
    end
  end
end
