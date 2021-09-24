defmodule Printer.Connection.VirtualTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Printer.Connection.Protocol, as: ConnectionProtocol
  alias Printer.Connection.Virtual

  setup do
    data = %{connection: Virtual.new()}

    {:ok, data}
  end

  describe "Virtual.open/1" do
    test "it spawns a virtual printer port", %{connection: connection} do
      assert connection.port == nil
      assert connection.reference == nil

      {:ok,
       %Virtual{
         port: port,
         reference: reference
       }} = ConnectionProtocol.open(connection)

      assert is_port(port)
      assert is_reference(reference)

      {:connected, pid} = Port.info(port, :connected)

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "it does nothing if a port is already open", %{connection: connection} do
      {:ok, connection} = ConnectionProtocol.open(connection)

      assert ConnectionProtocol.open(connection) == {:error, "Connection is already open"}
    end
  end

  describe "Virtual.close/1" do
    test "it closes a port if there's one open", %{connection: connection} do
      {:ok, connection} = ConnectionProtocol.open(connection)

      assert ConnectionProtocol.close(connection) == :ok

      assert Port.info(connection.port, :pid) == nil
    end

    test "it does nothing if there's no port open", %{connection: connection} do
      assert connection.port == nil
      assert connection.reference == nil

      assert ConnectionProtocol.close(connection) == :ok
    end
  end

  describe "Virtual.send/2" do
    test "it sends the message to the given port/pid", %{connection: connection} do
      {:ok, %{port: port} = connection} = ConnectionProtocol.open(connection)

      :erlang.trace(port, true, [:receive])

      me = self()

      ConnectionProtocol.send(connection, "G10\n")

      assert_receive {:trace, ^port, :receive, {^me, {:command, "G10\n"}}}, 1_000
    end
  end

  describe "Virtual.handle_message/2" do
    property "it returns port data", %{
      connection: connection
    } do
      {:ok, %{port: port} = connection} = ConnectionProtocol.open(connection)

      check all data <- binary() do
        assert ConnectionProtocol.handle_message(connection, {port, {:data, data}}) ==
                 {:ok, connection, data}
      end
    end

    test "it handles port close events", %{
      connection: connection
    } do
      {:ok, %{port: port, reference: reference} = connection} =
        ConnectionProtocol.open(connection)

      assert {:closed, ~s("It went boom")} ==
               ConnectionProtocol.handle_message(
                 connection,
                 {:DOWN, reference, :port, port, "It went boom"}
               )
    end

    test "it ignores other messages", %{connection: connection} do
      assert {:ok, connection} == ConnectionProtocol.handle_message(connection, :yo)
    end
  end
end
