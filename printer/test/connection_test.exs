defmodule Printer.ConnectionTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties
  use Norms

  alias Printer.Connection
  alias Printer.Connection.{InMemory, Overridable, Server}

  setup context do
    {:ok, server} = Server.start_link(printer_server: self())
    {:ok, connection} = InMemory.start()

    unless context[:no_open] do
      Connection.open(connection)
    end

    {:ok, %{connection: connection, server: server}}
  end

  describe "Connection.open/2" do
    @tag :no_open
    test "it calls open on the connection", %{connection: connection} do
      assert Connection.open(connection) == :ok
      assert_receive :connection_open
      assert InMemory.last_message(connection) == :open
    end

    test "it sends a :connection_open message if the connect was successful", %{
      connection: connection
    } do
      assert_receive :connection_open
      assert InMemory.last_message(connection) == :open
    end

    test "it returns an error if the connection is already open", %{connection: connection} do
      assert Connection.open(connection) == {:error, "Already connected"}
    end

    @tag :no_open
    property "it sends a :connection_open_failed message if open fails" do
      check all message <- binary() do
        connection = Overridable.new(open: fn _ -> {:error, message} end)

        assert Connection.open(connection) == :ok

        assert_receive {:connection_open_failed, ^message}
      end
    end

    test "it allows for an override", %{connection: old_connection} do
      {:ok, new_connection} = InMemory.start()

      assert Connection.open(new_connection, true) == :ok

      assert_receive :connection_open

      assert InMemory.last_message(new_connection) == :open
      assert InMemory.last_message(old_connection) == :close
    end
  end

  describe "Connection.close/1" do
    test "it calls close/1 on the connection", %{connection: connection} do
      assert Connection.close() == :ok
      assert InMemory.last_message(connection) == :close
    end

    @tag :no_open
    property "it returns the result of close" do
      check all message <- binary() do
        connection = Overridable.new(close: fn _ -> {:error, message} end)
        assert Connection.open(connection) == :ok
        assert Connection.close() == {:error, message}
      end
    end

    @tag :no_open
    test "it returns :ok when not connected" do
      assert Connection.close() == :ok
    end
  end

  describe "Connection.send/1" do
    property "it calls send/2 on the connection", %{connection: connection} do
      check all message <- binary() do
        assert Connection.send(message) == :ok
        assert InMemory.last_message(connection) == {:send, message}
      end
    end

    @tag :no_open
    property "it returns an error if not connected" do
      check all message <- binary() do
        assert Connection.send(message) == {:error, "Not connected"}
      end
    end

    property "it resturns the result of send/2" do
      check all error <- binary(),
                message <- binary() do
        connection = Overridable.new(send: fn _, _ -> {:error, error} end)

        assert Connection.open(connection, true) == :ok

        assert Connection.send(message) == {:error, error}
      end
    end
  end
end
