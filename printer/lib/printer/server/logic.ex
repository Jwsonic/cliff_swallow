defmodule Printer.Server.Logic do
  @moduledoc """
  Business logic functions/gaurds/macros to help make the server a bit more readable.
  """

  alias Printer.Connection
  alias Printer.Server.{Command, PrintJob, ResponseParser, State, Wait}

  require Logger

  defguard is_state(state) when is_struct(state, State)

  defguard is_connecting(state)
           when is_state(state) and
                  state.status == :connecting

  defguard is_connected(state)
           when is_state(state) and
                  state.status == :connected and
                  is_pid(state.connection_server)

  defguard is_waiting(state)
           when is_state(state) and
                  is_struct(state.wait, Wait)

  defguard is_printing(state)
           when is_state(state) and
                  state.status == :printing and
                  is_struct(state.print_job, PrintJob)

  defguard is_from_connection(state, connection_server)
           when is_state(state) and is_pid(connection_server) and
                  state.connection_server == connection_server

  def build_initial_state(_args \\ []) do
    %State{
      connection_server: nil,
      line_number: 1,
      previous_response: nil,
      print_job: nil,
      retry_count: 0,
      send_queue: :queue.new(),
      status: :disconnected,
      timeout_reference: nil,
      wait: Wait.new()
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

  @spec send_precheck(state :: State.t(), command :: String.t()) ::
          :ok
          | {:error, reason :: String.t()}

  def send_precheck(state, command)
      when is_printing(state) do
    case command do
      "M112" <> _rest -> :ok
      _command -> {:error, "Print job in progress"}
    end
  end

  def send_precheck(state, _command)
      when is_connected(state) do
    :ok
  end

  def send_precheck(_state, _command) do
    {:error, "Not connected"}
  end

  @spec reset_line_number(state :: State.t()) :: {:ok, state :: State.t()} | {:error, String.t()}
  def reset_line_number(state) when is_printing(state) do
    {:error, "Printing"}
  end

  def reset_line_number(state) when is_connected(state) do
    case Connection.send(state.connection_server, "M110 N1") do
      :ok ->
        state = %{state | line_number: 1, wait: Wait.new()}

        {:ok, state}

      {:error, _reason} = error ->
        error
    end
  end

  @spec send_command(state :: State.t(), command :: String.t()) ::
          {reply :: any(), state :: State.t()}
  def send_command(
        %State{
          connection_server: connection_server,
          line_number: line_number,
          wait: wait
        } = state,
        command
      ) do
    command = Command.new(command, line_number)
    wait = Wait.add(wait, command)
    command_to_send = to_string(command)

    Logger.info("Sending: #{command_to_send}")

    reply = Connection.send(connection_server, command_to_send)

    state = %{
      state
      | line_number: line_number + 1,
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

  @max_retry_count 10

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

  @spec next_command(state :: State.t()) ::
          {:no_commands, state :: :State.t()}
          | {state :: State.t(), command :: String.t()}
  def next_command(%State{} = state) when is_printing(state) do
    case PrintJob.next_command(state.print_job) do
      {:ok, command} -> {state, command}
      :done -> {%{state | status: :connected, print_job: nil}}
    end
  end

  def next_command(%State{send_queue: send_queue} = state) do
    case :queue.out(send_queue) do
      {:empty, _send_queue} -> :no_commands
      {{:value, command}, send_queue} -> {%{state | send_queue: send_queue}, command}
    end
  end

  @spec send_next(state :: State.t()) :: State.t()
  def send_next(%State{} = state) when is_printing(state) do
    case PrintJob.next_command(state.print_job) do
      {:ok, command} ->
        {_reply, state} = send_command(state, command)

        state

      :done ->
        %{state | status: :connected, print_job: nil}
    end
  end

  def send_next(%State{} = state) do
    case :queue.out(state.send_queue) do
      {:empty, _send_queue} ->
        state

      {{:value, command}, send_queue} ->
        {_reply, state} =
          %{state | send_queue: send_queue}
          |> send_command(command)

        state
    end
  end

  @spec resend_command(state :: State.t(), command :: Command.t()) :: State.t()
  def resend_command(%State{} = state, %Command{} = command) do
    wait = Wait.add(state.wait, command)

    Logger.info("Wait #{inspect(wait)}")

    command_to_send = to_string(command)

    Logger.info("Re-Sending: |#{command_to_send}|")

    result = Connection.send(state.connection_server, command_to_send)

    Logger.info("Send result: #{inspect(result)}")

    %{state | wait: wait}
  end

  @spec start_print(state :: State.t(), path :: Path.t()) ::
          {:ok, state :: State.t()} | {:error, reason :: String.t()}
  def start_print(state, _path) when is_printing(state) do
    {:error, "Print job in progress"}
  end

  def start_print(state, path) when is_connected(state) do
    with {:ok, print_job} <- PrintJob.new(path),
         {:ok, command} <- PrintJob.next_command(print_job),
         state <- %{state | status: :printing, print_job: print_job},
         {:ok, state} <- send_command(state, command) do
      {:ok, state}
    else
      {:error, reason} ->
        {:error, "Failed to start print job: #{inspect(reason)}"}

      {{:error, reason}, _state} ->
        {:error, "Failed to start print job: #{inspect(reason)}"}

      :done ->
        {:error, "Failed to start print, file seems to be emtpy"}
    end
  end

  def start_print(_state, _path) do
    {:error, "Not connected"}
  end

  @spec process_response(state :: State.t(), response :: String.t()) ::
          {:send_next, state :: State.t()}
          | {:resend, command :: Command.t(), state :: State.t()}
          | {:ignore, state :: State.t()}
  def process_response(
        %State{
          previous_response: previous_response,
          wait: wait
        } = state,
        response
      ) do
    Logger.info("Raw response: #{response}")

    parsed_response = ResponseParser.parse(response)

    state = %{state | previous_response: parsed_response}

    case {parsed_response, previous_response} do
      {:ok, {:resend, line_number}} ->
        case Wait.pop(wait, line_number) do
          :not_found ->
            {:ignore, state}

          {command, wait} ->
            state = %{state | wait: wait}

            {:resend, command, state}
        end

      {:ok, _} ->
        state = %{state | wait: Wait.pop(wait)}

        {:send_next, state}

      {{:ok, _temperature_data}, _} ->
        # TODO: temp updates
        state = %{state | wait: Wait.pop(wait)}

        {:send_next, state}

      {{:busy, reason}, _} ->
        Logger.warn("Printer busy: #{reason}")
        {:ignore, state}

      {{:parse_error, _reason}, _} ->
        Logger.error("Unable to parse response: #{response}")

        {:ignore, state}

      _other ->
        {:ignore, state}
    end
  end
end
