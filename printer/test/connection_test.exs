defmodule Printer.ConnectionTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties
  use Norms

  alias Printer.Connection
  alias Printer.Connection.{InMemory, Overridable}

  setup do
    {:ok, connection} = InMemory.start()
    {:ok, server} = Connection.open(connection, printer_server: self())

    {:ok, %{connection: connection, server: server}}
  end

  describe "Connection.open/2" do
    test "it calls open on the connection and sends a :connect_open message", %{
      connection: connection,
      server: server
    } do
      assert_receive {:connection_open, ^server}
      assert InMemory.last_message(connection) == :open
    end

    test "it sends a :connection_open_failed message if open fails" do
      connection = Overridable.new(open: fn _ -> {:error, "Failed"} end)

      assert {:ok, pid} = Connection.open(connection, printer_server: self())

      assert_receive {:connection_open_failed, ^pid, "Failed"}
    end

    test "it allows for many open connections at a time" do
      {:ok, connection1} = InMemory.start()
      {:ok, connection2} = InMemory.start()

      assert {:ok, pid1} = Connection.open(connection1, printer_server: self())
      assert_receive {:connection_open, ^pid1}

      assert {:ok, pid2} = Connection.open(connection2, printer_server: self())
      assert_receive {:connection_open, ^pid2}

      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
      assert pid1 != pid2
    end
  end

  describe "Connection.close/1" do
    test "it calls close/1 on the connection", %{connection: connection, server: server} do
      assert Connection.close(server) == :ok
      assert InMemory.last_message(connection) == :close
    end

    property "it returns the result of close" do
      connection = Overridable.new(close: fn _ -> {:error, "Failed"} end)
      assert {:ok, pid} = Connection.open(connection, printer_server: self())
      assert Connection.close(pid) == {:error, "Failed"}
    end
  end

  describe "Connection.send/1" do
    property "it calls send/2 on the connection", %{connection: connection, server: server} do
      check all message <- binary() do
        assert Connection.send(server, message) == :ok
        assert InMemory.last_message(connection) == {:send, message}
      end
    end

    property "it resturns the result of send/2" do
      check all error <- binary(),
                message <- binary() do
        connection = Overridable.new(send: fn _, _ -> {:error, error} end)

        assert {:ok, server} = Connection.open(connection, printer_server: self())

        assert Connection.send(server, message) == {:error, error}
      end
    end
  end
end
