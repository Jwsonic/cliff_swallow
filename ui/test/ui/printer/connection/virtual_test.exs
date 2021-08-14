defmodule Ui.Printer.Connection.VirtualTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: true

  alias Ui.Printer.Connection
  alias Ui.Printer.Connection.Virtual

  setup do
    connection = Virtual.new()

    {:ok, connection} = Connection.connect(connection)

    on_exit(fn -> Connection.disconnect(connection) end)

    {:ok, %{connection: connection}}
  end

  describe "Virtual.connect/1" do
    test "it spawns a virtual printer port" do
      connection = Virtual.new()

      assert connection.port == nil
      assert connection.reference == nil

      {:ok, connection} = Connection.connect(connection)

      assert is_port(connection.port)
      assert is_reference(connection.reference)

      Connection.disconnect(connection)
    end

    test "it does nothing if a port is already open", %{connection: connection} do
      assert is_port(connection.port)
      assert is_reference(connection.reference)

      {:ok, connection2} = Connection.connect(connection)

      assert connection.port == connection2.port
      assert connection.reference == connection2.reference
    end
  end

  describe "Virtual.disconnect/1" do
    test "it closes a port if there's one open", %{connection: connection} do
      assert is_port(connection.port)
      assert is_reference(connection.reference)

      Connection.disconnect(connection)

      Port.info(connection.port)
    end

    test "it does nothing if there's no port open", %{connection: connection} do
      assert connection.port == nil
      assert connection.reference == nil

      assert Connection.disconnect(connection) == :ok
    end
  end

  describe "Virtual.send/2" do
    test "it sends the message to the given port/pid", %{connection: connection} do
      {:ok, connection} = Connection.connect(connection)

      Connection.send(connection, "G10\n")

      assert_receive {_pid, {:connection_data, "ok"}}, 1_000
    end
  end

  describe "Virtual.update/2" do
    test "it forwards port messages as connection messages"
    test "it handles port close events"
    test "it ignores other messages"
  end
end
