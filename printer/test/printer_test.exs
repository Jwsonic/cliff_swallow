defmodule PrinterTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties
  use Norms

  alias Printer.Connection.{InMemory, Overridable}
  alias Printer.{Gcode, State}

  setup context do
    {:ok, connection} = InMemory.start()

    unless context[:no_connect] do
      Printer.connect(connection)
    end

    on_exit(&Printer.disconnect/0)

    {:ok, %{connection: connection}}
  end

  describe "Printer.connect/2" do
    @tag :no_connect
    test "it connects when there is no connection", %{connection: connection} do
      assert_printer_status(:disconnected)
      assert Printer.connect(connection) == :ok
      assert InMemory.last_command(connection) == :connect
      assert_printer_status(:connected)
    end

    @tag :no_connect
    test "it calls connect on the connection", %{connection: connection} do
      assert InMemory.last_command(connection) == nil
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

    property "failing overrides lead to a disconnected state", %{connection: connection} do
      check all error <- binary() do
        assert InMemory.last_command(connection) == :connect

        Printer.connect(Overridable.new(open: fn -> {:error, error} end), [:override])

        assert InMemory.last_command(connection) == :disconnect
        assert :sys.get_state(Printer).status == :disconnected
      end
    end

    test "it returns an error when already connected" do
      {:ok, new_connection} = InMemory.start()

      assert Printer.connect(new_connection) == {:error, "Already connected"}
    end
  end

  describe "Printer.disconnect" do
    test "it calls disconnect on the connection", %{connection: connection} do
      assert Printer.disconnect() == :ok
      assert InMemory.last_command(connection) == :disconnect
    end

    test "it changes the printer state to disconnected" do
      assert_printer_status(:connected)
      assert Printer.disconnect() == :ok
      assert_printer_status(:disconnected)
    end
  end

  describe "Printer.state/0" do
    test "it returns the current printer state" do
      assert {:ok, %State{}} = Printer.state()
    end
  end

  describe "Printer.extrude/1" do
    property "it sends a G1 command with extrude param", %{connection: connection} do
      check all amount <- Norm.gen(int_or_float()) do
        assert Printer.extrude(amount) == :ok
        assert InMemory.last_command(connection) == {:send, "G1 E#{amount}\n"}
      end
    end
  end

  describe "Printer.heat_hotend/1" do
    property "it sends a M104 command", %{connection: connection} do
      check all temperature <- Norm.gen(int_or_float()) do
        assert Printer.heat_hotend(temperature) == :ok
        assert InMemory.last_command(connection) == {:send, Gcode.m104(temperature)}
      end
    end
  end

  describe "Printer.head_bed/1" do
    property "it sends a M140 command", %{connection: connection} do
      check all temperature <- Norm.gen(int_or_float()) do
        assert Printer.heat_bed(temperature) == :ok
        assert InMemory.last_command(connection) == {:send, Gcode.m140(temperature)}
      end
    end
  end

  describe "Printer.start_temperature_report/1" do
    property "It sends a M155 command with an interval param", %{connection: connection} do
      check all interval <- Norm.gen(spec(is_integer() and (&(&1 >= 0)))) do
        assert Printer.start_temperature_report(interval) == :ok
        assert InMemory.last_command(connection) == {:send, Gcode.m155(interval)}
      end
    end
  end

  describe "Printer.stop_temperature_report/0" do
    property "It sends a M155 command with an interval of 0", %{connection: connection} do
      assert Printer.stop_temperature_report() == :ok
      assert InMemory.last_command(connection) == {:send, Gcode.m155(0)}
    end
  end

  @axes_combinations [
    ["X", "Y", "Z"],
    ["Y", "Z"],
    ["X", "Z"],
    ["X", "Y"],
    ["X"],
    ["Y"],
    ["Z"]
  ]

  describe "Printer.home/1" do
    test "it sends a G28 command with axes to home", %{connection: connection} do
      for axes <- @axes_combinations do
        assert Printer.home(axes) == :ok
        assert InMemory.last_command(connection) == {:send, Gcode.g28(axes)}
      end
    end

    test "you can't pass an empty list" do
      assert_raise Norm.MismatchError, fn -> Printer.home([]) end
    end
  end

  describe "Printer.move/1" do
    property "it sends a G0 command with axes params", %{connection: connection} do
      check all index <- integer(0..length(@axes_combinations)),
                keys = Enum.at(@axes_combinations, index),
                values <- list_of(integer(), length: length(keys)),
                axes = keys |> Enum.zip(values) |> Map.new() do
        assert Printer.move(axes) == :ok
        assert InMemory.last_command(connection) == {:send, Gcode.g0(axes)}
      end
    end

    test "you can't pass an empty list" do
      assert_raise Norm.MismatchError, fn -> Printer.move([]) end
    end
  end

  defp assert_printer_status(status) do
    {:ok, %{status: actual_status}} = Printer.state()

    assert status == actual_status
  end
end
