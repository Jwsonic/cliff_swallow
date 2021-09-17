defmodule Printer.Connection.Server.LogicTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Printer.Connection.Overridable
  alias Printer.Connection.Server.{Logic, State}

  describe "Logic.handle_response/2" do
    property ":ok handle_response/2 does nothing" do
      check all message <- binary() do
        state = %State{
          connection: Overridable.new(),
          printer_server: self()
        }

        assert Logic.handle_response(state, message) == state
      end
    end

    property ":closed handle_response/2 sends a :connection_closed message and updates state" do
      check all message <- binary() do
        state = %State{
          connection: Overridable.new(handle_response: fn _, _ -> :closed end),
          printer_server: self()
        }

        assert Logic.handle_response(state, message) == %{state | connection: nil}

        assert_receive :connection_closed
      end
    end

    property "{:ok, response} handle_response/2 sends a :connection_response message" do
      check all message <- binary() do
        state = %State{
          connection: Overridable.new(handle_response: fn _, message -> {:ok, message} end),
          printer_server: self()
        }

        assert Logic.handle_response(state, message) == state

        assert_receive {:connection_response, ^message}
      end
    end

    property "{:error, error} handle_response/2 sends a :connection_error message" do
      check all message <- binary() do
        state = %State{
          connection: Overridable.new(handle_response: fn _, message -> {:error, message} end),
          printer_server: self()
        }

        assert Logic.handle_response(state, message) == state

        assert_receive {:connection_error, ^message}
      end
    end
  end
end
