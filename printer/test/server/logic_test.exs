defmodule Printer.Server.LogicTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Printer.Connection
  alias Printer.Connection.InMemory
  alias Printer.Server.{Logic, PrintJob, State, Wait}

  setup do
    {:ok, connection} = InMemory.start_link()
    {:ok, connection_server} = Connection.open(connection)

    state = %State{
      connection_server: connection_server,
      retry_count: 0,
      send_queue: :queue.new(),
      status: :connected
    }

    {:ok, %{connection: connection, state: state}}
  end

  describe "connect_precheck/2" do
    test "returns :already_connected if there's a connection" do
      assert Logic.connect_precheck(
               %State{
                 connection_server: nil,
                 status: :connected
               },
               false
             ) ==
               :already_connected
    end

    test "override?=true calls Connection.close/1", %{connection: connection, state: state} do
      Logic.connect_precheck(state, true)

      assert InMemory.last_message(connection) == :close
    end

    test "disconnected returns ok" do
      assert Logic.connect_precheck(%State{status: :disconnected}, false) == :ok
    end
  end

  describe "open_connection/2" do
    test "calls Connection.open/1 on the connection" do
      {:ok, connection} = InMemory.start_link()
      state = Logic.build_initial_state()

      assert Logic.open_connection(state, connection) ==
               {:ok,
                %{
                  state
                  | connection_server: nil,
                    status: :connecting
                }}

      assert_receive {:connection_open, _connection_server, ^connection}

      assert InMemory.last_message(connection) == :open
    end
  end

  describe "connected/2" do
    test "updates the state to mark :connected" do
      state = %State{}

      assert Logic.connected(state, self()) == %{
               state
               | connection_server: self(),
                 status: :connected
             }
    end
  end

  describe "send_precheck/2" do
    property "only estop is ok during a print job", %{state: state} do
      state = %{state | status: :printing, print_job: %PrintJob{}}

      assert Logic.send_precheck(state, "M112") == :ok

      check all command <- binary(),
                command != "M112" do
        assert Logic.send_precheck(state, command) == {:error, "Print job in progress"}
      end
    end

    property "anything is ok when connected", %{state: state} do
      check all command <- binary() do
        assert Logic.send_precheck(state, command) == :ok
      end
    end

    property "nothing is ok when disconnected", %{state: state} do
      state = %{state | status: :disconnected}

      check all command <- binary() do
        assert Logic.send_precheck(state, command) == {:error, "Not connected"}
      end
    end
  end

  describe "send_command/2" do
    property "calls Connection.send/2", %{connection: connection, state: state} do
      check all command <- binary() do
        Logic.send_command(state, command)

        assert InMemory.last_message(connection) == {:send, command}
      end
    end

    property "updates the state", %{state: state} do
      check all command <- binary() do
        {:ok,
         %{
           timeout_reference: timeout_reference,
           wait: %Wait{}
         }} = Logic.send_command(state, command)

        assert is_reference(timeout_reference)
      end
    end

    test "schedules a timeout", %{connection: connection, state: state} do
      {_reply,
       %{
         timeout_reference: timeout_reference,
         wait: %{timeout: timeout}
       }} = Logic.send_command(state, "G0")

      assert InMemory.last_message(connection) == {:send, "G0"}

      assert_receive {:send_timeout, ^timeout_reference}, timeout + 100
    end
  end

  describe "check_wait/2" do
    test "it returns :done when the response matches", %{state: state} do
      state = %{state | timeout_reference: make_ref(), wait: Wait.build("G0 X1")}

      assert Logic.check_wait(state, "ok") ==
               {:done, %{state | timeout_reference: nil, wait: nil}}
    end

    property "it returns :wait with new state when we need to wait longer", %{state: state} do
      state = %{state | wait: Wait.build("G0 X1")}

      check all response <- binary(),
                response != "ok" do
        {:wait, %State{}} = assert Logic.check_wait(state, response)
      end
    end

    test "it handles multiple response commands", %{state: state} do
      state = %{state | wait: Wait.build("M109 ")}

      {:wait, %State{} = state} = Logic.check_wait(state, "ok")

      {:wait, %State{} = state} = Logic.check_wait(state, "T: ")

      assert {:done, %State{}} = Logic.check_wait(state, "ok")
    end

    test "returns :done when not waiting", %{state: state} do
      check all response <- binary() do
        assert Logic.check_wait(state, response) == {:done, state}
      end
    end
  end

  describe "check_timeout/2" do
    test "it returns :ingore when the timeout can be ignored",
         %{state: state} do
      assert Logic.check_timeout(state, make_ref()) == :ignore
    end

    test "it returns :retry when the command should be sent again",
         %{state: state} do
      timeout_reference = make_ref()

      state = %{
        state
        | timeout_reference: timeout_reference,
          wait: %Wait{}
      }

      assert Logic.check_timeout(state, timeout_reference) ==
               :retry
    end
  end

  describe "retry_send_command/1" do
    test "sends the command again", %{state: state} do
      {_reply, state} = Logic.send_command(state, "G0")

      retry_count = state.retry_count + 1

      assert {:ok, %{retry_count: ^retry_count}} = Logic.retry_send_command(state)
    end

    test "returns an error when over the retry limit", %{state: state} do
      {_reply, state} = Logic.send_command(state, "G0")

      state = %{state | retry_count: 10}

      assert Logic.retry_send_command(state) ==
               {:error, "Over max retry count for G0"}
    end
  end

  describe "next_command/1" do
    test "returns :no_commands and clears the timeout reference", %{state: state} do
      assert :no_commands == Logic.next_command(state)
    end

    property "returns updated state and command when there are messages", %{state: state} do
      check all command <- binary() do
        new_state = %{state | send_queue: :queue.in(command, state.send_queue)}

        assert Logic.next_command(new_state) == {state, command}
      end
    end

    test "when printing, returns the next print job command", %{state: state} do
      state = %{
        state
        | status: :printing,
          print_job: %PrintJob{
            pid: File.open!("priv/calicat.gcode"),
            path: "priv/calicat.gcode",
            start_time: DateTime.utc_now()
          }
      }

      assert Logic.next_command(state) == {state, "M140 S60\n"}
      assert Logic.next_command(state) == {state, "M105\n"}
      assert Logic.next_command(state) == {state, "M190 S60\n"}
    end
  end

  describe "add_to_send_queue/2" do
    property "adds command to the send queue", %{state: state} do
      check all command <- binary() do
        assert Logic.add_to_send_queue(state, command) == %{
                 state
                 | send_queue: :queue.in(command, state.send_queue)
               }
      end
    end
  end

  describe "close_connection/1" do
    test "closes the active connection",
         %{connection: connection, state: state} do
      state = %{state | retry_count: 3}

      assert Logic.close_connection(state) == %{
               state
               | connection_server: nil,
                 status: :disconnected,
                 retry_count: 0
             }

      assert InMemory.last_message(connection) == :close
    end
  end
end
