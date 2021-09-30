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
                  is_pid(state.connection)

  defguard is_waiting(state) when is_state(state) and state.wait != nil

  defguard is_from_connection(state, connection)
           when is_state(state) and is_pid(connection) and state.connection == connection

  def build_initial_state(_args) do
    %State{
      connection: nil,
      send_queue: :queue.new(),
      status: :disconnected,
      wait: nil
    }
  end

  # override? -> true means always connect and maybe disconnect too
  @spec connect_precheck(state :: State.t(), override? :: boolean()) :: :ok
  def connect_precheck(%State{connection: connection}, true) do
    if is_pid(connection) do
      Connection.close(connection)
    end

    :ok
  end

  # :disconnected status means it's ok to connect
  def connect_precheck(%State{status: :disconnected}, _override?), do: :ok

  # Otherwise its an error
  def connect_precheck(_state, _override?), do: :already_connected

  @spec close_connection(state :: State.t()) :: State.t()
  def close_connection(%State{connection: connection}) do
    if Process.alive?(connection) do
      Connection.close(connection)
    end

    :ok
  end

  @spec send_command(state :: State.t(), command :: String.t()) ::
          {reply :: any(), state :: State.t()}
  def send_command(%State{} = state, command) do
    reply = Connection.send(state.connection, command)
    state = update_wait(state, command)

    {reply, state}
  end

  @spec check_wait(state :: State.t(), response :: String.t()) ::
          {:wait, state :: State.t()} | {:done, State.t()}
  def check_wait(%State{wait: wait} = state, response) do
    case Wait.check(wait, response) do
      :done -> {:done, %{state | wait: nil}}
      {:wait, wait} -> {:wait, %{state | wait: wait}}
    end
  end

  @spec next_command(state :: State.t()) ::
          {:no_commands, state :: :State.t()} | {state :: State.t(), command :: String.t()}
  def next_command(%State{send_queue: send_queue} = state) do
    case :queue.out(send_queue) do
      {:empty, _send_queue} -> {:no_commands, state}
      {{:value, command}, send_queue} -> {%{state | send_queue: send_queue}, command}
    end
  end

  @spec update_connecting(state :: State.t()) :: State.t()
  def update_connecting(%State{} = state) do
    %{
      state
      | connection: nil,
        status: :connecting
    }
  end

  @spec update_connected(state :: State.t(), connection :: pid()) :: State.t()
  def update_connected(%State{} = state, connection) do
    %{
      state
      | connection: connection,
        status: :connected
    }
  end

  @spec update_disconnected(state :: State.t()) :: State.t()
  def update_disconnected(%State{} = state) do
    %{
      state
      | connection: nil,
        status: :disconnected
    }
  end

  @spec update_add_send_queue(state :: State.t(), command :: String.t()) :: State.t()
  def update_add_send_queue(%State{send_queue: send_queue} = state, command) do
    %{
      state
      | send_queue: :queue.in(command, send_queue)
    }
  end

  @spec update_wait(state :: State.t(), command :: String.t()) :: State.t()
  def update_wait(%State{} = state, command) do
    %{
      state
      | wait: Wait.build(command)
    }
  end
end
