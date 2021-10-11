defmodule Printer.Server.Logic do
  @moduledoc """
  Business logic functions/gaurds/macros to help make the server a bit more readable.

  This could(should?) probably be broken down more in the future.
  """

  alias Printer.{Connection, Gcode, PubSub, Status}
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
      public_status: %Status{
        status: :disconnected
      },
      retry_count: 0,
      send_queue: :queue.new(),
      status: :disconnected,
      timeout_reference: nil,
      wait: Wait.new()
    }
  end

  def reset(args \\ []) do
    state = build_initial_state(args)

    PubSub.broadcast(state.public_status)

    state
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
        state =
          update_state(state, %{
            connection_server: nil,
            status: :connecting
          })

        {:ok, state}

      {:error, reason} ->
        state =
          update_state(state, %{
            connection_server: nil,
            status: :disconnected
          })

        {:error, reason, state}
    end
  end

  @spec connected(state :: State.t(), connection_server :: pid()) :: State.t()
  def connected(%State{} = state, connection_server) do
    interval_command = Gcode.m155(5)

    {_reply, state} =
      state
      |> update_state(%{
        connection_server: connection_server,
        status: :connected
      })
      |> send_command(interval_command)

    state
  end

  @spec close_connection(state :: State.t()) :: State.t()
  def close_connection(%State{connection_server: connection_server}) do
    if is_pid(connection_server) && Process.alive?(connection_server) do
      Connection.close(connection_server)
    end

    reset()
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
        state = update_state(state, %{line_number: 1, wait: Wait.new()})

        {:ok, state}

      {:error, _reason} = error ->
        error
    end
  end

  @spec send_command(state :: State.t(), command :: String.t()) ::
          {reply :: any(), state :: State.t()}
  def send_command(
        %State{
          line_number: line_number
        } = state,
        command
      ) do
    command = Command.new(command, line_number)

    {reply, state} = do_send_command(state, command)

    state =
      update_state(state, %{
        line_number: line_number + 1
      })

    {reply, state}
  end

  @max_retry_count 5

  @spec resend_command(state :: State.t(), command :: Command.t()) :: State.t()
  def resend_command(
        %State{
          retry_count: retry_count
        } = state,
        %Command{} = command
      ) do
    case retry_count > @max_retry_count do
      true ->
        Logger.error("Over max retry count. Closing the connection.")

        close_connection(state)

      false ->
        to_resend = to_string(command)

        Logger.info("Re-Sending: |#{to_resend}|")

        {_reply, state} = do_send_command(state, command)

        update_state(state, %{
          retry_count: retry_count + 1
        })
    end
  end

  defp do_send_command(
         %State{
           connection_server: connection_server,
           wait: wait
         } = state,
         %Command{} = command
       ) do
    wait = Wait.add(wait, command)
    command_to_send = to_string(command)

    Logger.info("Sending: #{command_to_send}")

    reply = Connection.send(connection_server, command_to_send)

    timeout_reference = make_ref()

    timeout = Wait.timeout(command)

    Process.send_after(
      self(),
      {
        :timeout,
        timeout_reference,
        command
      },
      timeout
    )

    state =
      update_state(state, %{
        timeout_reference: timeout_reference,
        wait: wait
      })

    {reply, state}
  end

  @spec add_to_send_queue(state :: State.t(), command :: String.t()) :: State.t()
  def add_to_send_queue(%State{send_queue: send_queue} = state, command) do
    update_state(state, %{
      send_queue: :queue.in(command, send_queue)
    })
  end

  @spec send_next(state :: State.t()) :: State.t()
  def send_next(%State{} = state) when is_printing(state) do
    case PrintJob.next_command(state.print_job) do
      {:ok, command} ->
        {_reply, state} = send_command(state, command)

        state

      :done ->
        update_state(state, %{
          status: :connected,
          print_job: nil
        })
    end
  end

  def send_next(%State{} = state) do
    case :queue.out(state.send_queue) do
      {:empty, _send_queue} ->
        state

      {{:value, command}, send_queue} ->
        {_reply, state} =
          state
          |> update_state(%{send_queue: send_queue})
          |> send_command(command)

        state
    end
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
        %State{} = state,
        response
      ) do
    parsed_response = ResponseParser.parse(response)

    {response, state} = do_process_response(state, parsed_response)

    state =
      update_state(state, %{
        previous_response: parsed_response
      })

    {response, state}
  end

  # We just got the "ok" portion of a resend response. So we'll re-send the requested line
  defp do_process_response(
         %State{
           previous_response: {:resend, line_number},
           wait: wait
         } = state,
         :ok
       ) do
    case Wait.remove(wait, line_number) do
      :not_found ->
        {:ignore, state}

      {command, wait} ->
        state = update_state(state, %{wait: wait})
        {:resend, command, state}
    end
  end

  # It looks like we're halfway through a resend request,
  # wait for the next part
  defp do_process_response(
         %State{} = state,
         {:resend, _line_number}
       ) do
    {:ignore, state}
  end

  # We've got a non-retry "ok" response.
  # Clear the retry values and send the next command
  defp do_process_response(
         %State{wait: wait} = state,
         :ok
       ) do
    wait = Wait.remove_lowest(wait)

    state =
      update_state(state, %{
        retry_count: 0,
        timeout_reference: nil,
        wait: wait
      })

    {:send_next, state}
  end

  # We've been sent some temperature data so update the state only
  defp do_process_response(
         %State{} = state,
         {:ok, temperature_data}
       ) do
    state = update_state(state, temperature_data)

    {:ignore, state}
  end

  defp do_process_response(
         %State{} = state,
         {:busy, reason}
       ) do
    Logger.warn("Printer busy: #{reason}")
    {:ignore, state}
  end

  defp do_process_response(
         %State{} = state,
         {:parse_error, reason}
       ) do
    Logger.warn("Parse error: #{reason}")

    {:ignore, state}
  end

  defp do_process_response(%State{} = state, _other) do
    {:ignore, state}
  end

  @spec set_line_number(
          state :: State.t(),
          line_number :: pos_integer()
        ) :: State.t()
  def set_line_number(state, line_number) do
    new_state = update_state(state, %{line_number: line_number})

    case send_command(new_state, "M110") do
      {:ok, state} ->
        {:ok, state}

      result ->
        result
    end
  end

  def check_timeout(
        %State{
          timeout_reference: timeout_reference
        },
        timeout_reference
      ) do
    :retry
  end

  def check_timeout(_state, _timeout_reference), do: :ignore

  @keys [
    :connection_server,
    :print_job,
    :retry_count,
    :send_queue,
    :line_number,
    :previous_response,
    :public_status,
    :status,
    :timeout_reference,
    :wait
  ]

  # Find a better way to broadcast changes
  def update_state(
        %State{
          public_status: old_public_status
        } = state,
        changes
      ) do
    public_status = Status.update(old_public_status, changes)

    if old_public_status != public_status do
      PubSub.broadcast(public_status)
    end

    changes = Map.take(changes, @keys)

    state
    |> Map.merge(changes)
    |> Map.put(:public_status, public_status)
  end
end
