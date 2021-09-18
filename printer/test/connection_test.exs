defmodule Printer.ConnectionTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties
  use Norms

  alias Printer.Connection
  alias Printer.Connection.{Echo, Overridable}

  setup do
    {:ok, server} = Connection.open(Echo.new(), printer_server: self())

    {:ok, %{server: server}}
  end

  describe "Connection.open/2" do
    test "it calls open on the connection and sends a :connect_open message", %{
      server: server
    } do
      assert_receive {Echo, :open}
      assert_receive {:connection_open, ^server}
    end

    test "it sends a :connection_open_failed message if open fails" do
      connection = Overridable.new(open: fn _ -> {:error, "Failed"} end)

      assert {:ok, pid} = Connection.open(connection, printer_server: self())

      assert_receive {:connection_open_failed, ^pid, "Failed"}
    end

    test "it allows for many open connections at a time", %{server: server1} do
      assert_receive {:connection_open, ^server1}

      assert {:ok, server2} = Connection.open(Echo.new(), printer_server: self())
      assert_receive {:connection_open, ^server2}

      assert Process.alive?(server1)
      assert Process.alive?(server2)
      assert server1 != server2
    end
  end

  describe "Connection.close/1" do
    test "it calls close/1 on the connection", %{server: server} do
      assert_receive {:connection_open, ^server}, 1_000
      assert Connection.close(server) == :ok
      assert_receive {Echo, :close}, 1_000
    end

    property "it returns the result of close" do
      check all error <- binary() do
        connection = Overridable.new(close: fn _ -> {:error, error} end)

        assert {:ok, server} = Connection.open(connection, printer_server: self())
        assert Connection.close(server) == {:error, error}
      end
    end
  end

  describe "Connection.send/1" do
    property "it calls send/2 on the connection", %{server: server} do
      check all message <- binary() do
        assert Connection.send(server, message) == :ok
        assert_receive {Echo, {:send, ^message}}
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
