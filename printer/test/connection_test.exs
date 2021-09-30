defmodule Printer.ConnectionTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Printer.Connection
  alias Printer.Connection.{InMemory, Overridable}

  setup do
    {:ok, connection} = InMemory.start_link()
    {:ok, server} = Connection.open(connection)

    {:ok, %{connection: connection, server: server}}
  end

  describe "Connection.open/2" do
    test "it calls open/1 on the connection and sends a :connect_open message", %{
      connection: connection,
      server: server
    } do
      assert InMemory.last_message(connection) == :open

      assert_receive {:connection_open, ^server, ^connection}
    end

    test "it sends a :connection_open_failed message if open/1 fails" do
      {:ok, connection} = Overridable.new(open: fn _ -> {:error, "Failed"} end)

      assert {:ok, server} = Connection.open(connection)

      assert_receive {:connection_open_failed, ^server, "Failed"}
    end

    test "it allows for many open connections at a time", %{
      connection: connection,
      server: server1
    } do
      assert_receive {:connection_open, ^server1, ^connection}

      {:ok, connection2} = InMemory.start_link()

      assert {:ok, server2} = Connection.open(connection2)
      assert_receive {:connection_open, ^server2, ^connection2}

      assert Process.alive?(server1)
      assert Process.alive?(server2)
      assert server1 != server2
    end
  end

  describe "Connection.close/1" do
    test "it calls close/1 on the connection", %{connection: connection, server: server} do
      assert_receive {:connection_open, ^server, ^connection}, 1_000
      assert Connection.close(server) == :ok
      assert InMemory.last_message(connection) == :close
    end

    property "it returns the error result of close/1", %{server: server} do
      assert Connection.close(server) == :ok

      check all error <- binary() do
        {:ok, connection} = Overridable.new(close: fn _ -> {:error, error} end)

        assert {:ok, server} = Connection.open(connection)
        assert Connection.close(server) == {:error, error}
      end
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
        {:ok, connection} = Overridable.new(send: fn _, _ -> {:error, error} end)

        assert {:ok, server} = Connection.open(connection)

        assert Connection.send(server, message) == {:error, error}
      end
    end
  end
end
