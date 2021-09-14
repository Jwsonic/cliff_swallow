defmodule PrinterTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties
  use Norms

  alias Printer.Connection.{Failing, InMemory}

  setup context do
    {:ok, connection} = InMemory.start()

    unless context[:no_connect] do
      Printer.connect(connection)
    end

    on_exit(&Printer.disconnect/0)

    {:ok, %{connection: connection}}
  end

  describe "Printer.heat_hotend/1" do
    property "it sends a M109 command", %{connection: connection} do
      check all(temperature <- Norm.gen(int_or_float())) do
        assert Printer.heat_hotend(temperature) == :ok
        assert InMemory.last_command(connection) == {:send, "M109 S#{temperature}\n"}
      end
    end
  end

  describe "Printer.connect/2" do
    @tag :no_connect
    test "it connects when there is no connection", %{connection: connection} do
      assert Printer.connect(connection) == :ok
      assert InMemory.last_command(connection) == :connect
    end

    test "it overrides the exisiting connection when the option is given", %{
      connection: connection
    } do
      {:ok, new_connection} = InMemory.start()

      assert Printer.connect(new_connection, [:override]) == :ok
      assert InMemory.last_command(connection) == :disconnect
      assert InMemory.last_command(new_connection) == :connect
    end

    test "if failing overrides lead to a disconnected state", %{connection: connection} do
      assert InMemory.last_command(connection) == :connect

      Printer.connect(%Failing{}, [:override])

      assert InMemory.last_command(connection) == :disconnect
      # TODO: check printer state
    end

    test "it returns an error when already connected" do
      {:ok, new_connection} = InMemory.start()

      assert Printer.connect(new_connection) == {:error, "Already connected"}
    end
  end
end
