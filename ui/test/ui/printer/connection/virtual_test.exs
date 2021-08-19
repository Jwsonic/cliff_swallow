defmodule Ui.Printer.Connection.VirtualTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: true

  alias Ui.Printer.Connection
  alias Ui.Printer.Connection.Virtual

  setup context do
    connection = Virtual.new()

    connection =
    case context[:no_connect] do
      true -> connection
      _ ->
        {:ok, connection} = Connection.connect(connection)

        on_exit(fn -> Connection.disconnect(connection) end)

        connection
    end

    {:ok, %{connection: connection}}
  end

  describe "Virtual.connect/1" do

    @tag :no_connect
    test "it spawns a virtual printer port", %{connection: connection} do
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

    @tag :no_connect
    test "it does nothing if there's no port open", %{connection: connection} do
      assert connection.port == nil
      assert connection.reference == nil

      assert Connection.disconnect(connection) == :ok
    end
  end

  describe "Virtual.send/2" do
    test "it sends the message to the given port/pid", %{connection: %{port: port} = connection} do
      :erlang.trace(port, true,  [:receive])

      me = self()

      Connection.send(connection, "G10\n")

      assert_receive {:trace, ^port, :receive, {^me, {:command, "G10\n"}}}, 1_000
    end
  end

  describe "Virtual.update/2" do
    test "it forwards port messages as connection messages", %{connection: %{port: port} = connection} do
      {:ok, _connection} = Connection.update(connection, {port, {:data, "test"}})

      assert_receive {:connection_data, "test"}
    end

    test "it handles port close events", %{connection: %{port: port, reference: reference} = connection}  do
      assert {:error, ~s(Port closed: "It went boom")} == Connection.update(connection, {:DOWN, reference, :port, port, "It went boom"})
    end

    test "it ignores other messages", %{connection: connection} do
      assert {:ok, connection} == Connection.update(connection, :yo)
    end
  end
end
