defmodule PrinterTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: true

  alias Printer.Connection.InMemory

  setup do
    {:ok, connection} = InMemory.start()

    Printer.connect(connection)

    {:ok, %{connection: connection}}
  end

  describe "Printer.heat/1" do
    test "it sends a M109 command", %{connection: connection} do
      Printer.heat(100)

      assert InMemory.commands(connection) == [{:send, "M109 S100\n"}, :connect]
    end
  end
end
