defmodule Printer.Server.LogicTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Printer.Server.{Logic, State, Wait}

  setup do
    state = %State{
      connection: self(),
      send_queue: :queue.new(),
      status: :connected
    }

    {:ok, %{state: state}}
  end

  describe "connect_precheck/2" do
    test "returns :already_connected if there's a connection" do
      assert Logic.connect_precheck(%State{connection: self(), status: :connected}, false) ==
               :already_connected
    end

    test "override?=true calls Connection.close/1", %{state: state} do
      Task.async(fn -> Logic.connect_precheck(state, true) end)

      assert_receive {:"$gen_call", {_pid, _ref}, :close}
    end

    test "disconnected returns ok" do
      assert Logic.connect_precheck(%State{status: :disconnected}, false) == :ok
    end
  end

  describe "send_command/2" do
    property "calls Connection.send/2", %{state: state} do
      check all command <- binary() do
        Task.async(fn -> Logic.send_command(state, command) end)

        assert_receive {:"$gen_call", {_pid, _ref}, {:send, ^command}}
      end
    end

    property "updates the state with a new wait", %{state: state} do
      check all command <- binary() do
        state = %{
          state
          | connection: :none
        }

        expected_state = %{state | wait: Wait.build(command)}

        assert Logic.send_command(state, command) == {:ok, expected_state}
      end
    end
  end

  describe "check_wait/2" do
    test "it returns :done when the response matches", %{state: state} do
      state = %{state | wait: Wait.build("G0 X1")}

      assert Logic.check_wait(state, "ok") == {:done, %{state | wait: nil}}
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
  end

  describe "next_command/1" do
    test "returns :no_commands and same state when the queue is empty", %{state: state} do
      assert {:no_commands, state} == Logic.next_command(state)
    end

    property "returns updated state and command when there are messages", %{state: state} do
      check all command <- binary() do
        new_state = %{state | send_queue: :queue.in(command, state.send_queue)}

        assert Logic.next_command(new_state) == {state, command}
      end
    end
  end
end
