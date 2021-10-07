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
    test "it spawns a virtual printer pid", %{connection: connection} do
      assert connection.pid == nil

      {:ok,
       %Virtual{
         pid: pid
       }} = ConnectionProtocol.open(connection)

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "it does nothing if a pid is already open", %{connection: connection} do
      {:ok, connection} = ConnectionProtocol.open(connection)

      assert ConnectionProtocol.open(connection) == {:error, "Connection is already open"}
    end
  end

  describe "Virtual.close/1" do
    test "it closes a pid if there's one open", %{connection: connection} do
      {:ok, %{pid: pid} = connection} = ConnectionProtocol.open(connection)

      assert Process.alive?(pid)

      assert ConnectionProtocol.close(connection) == :ok

      refute Process.alive?(pid)
    end

    test "it does nothing if there's no pid open", %{connection: connection} do
      assert connection.pid == nil

      assert ConnectionProtocol.close(connection) == :ok
    end
  end

  describe "Virtual.send/2" do
    test "it sends the message to the given pid", %{connection: connection} do
      {:ok, %{pid: pid} = connection} = ConnectionProtocol.open(connection)

      :erlang.trace(pid, true, [:receive])

      me = self()

      ConnectionProtocol.send(connection, "G10\n")

      assert_receive {:trace, ^pid, :receive,
                      {
                        :"$gen_call",
                        {^me, _ref},
                        {:call, :virtual, :write, ["G10\n"], []}
                      }},
                     1_000
    end
  end

  describe "Virtual.handle_message/2" do
    property "it returns pid data", %{
      connection: connection
    } do
      {:ok, connection} = ConnectionProtocol.open(connection)

      check all data <- binary() do
        assert ConnectionProtocol.handle_message(connection, {:virtual_printer, data}) ==
                 {:ok, connection, data}
      end
    end

    test "it handles pid close events", %{
      connection: connection
    } do
      {:ok, %{pid: pid} = connection} = ConnectionProtocol.open(connection)

      assert {:closed, ~s("It went boom")} ==
               ConnectionProtocol.handle_message(
                 connection,
                 {:DOWN, make_ref(), :process, pid, "It went boom"}
               )
    end

    test "it ignores other messages", %{connection: connection} do
      assert {:ok, connection} == ConnectionProtocol.handle_message(connection, :yo)
    end
  end
end
