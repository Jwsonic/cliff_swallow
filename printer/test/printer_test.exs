defmodule PrinterTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Printer.Connection.{Echo, Overridable}
  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  setup do
    on_exit(fn -> Printer.disconnect() end)

    pid = Process.whereis(PrinterServer)
    :erlang.trace(pid, true, [:receive])

    {:ok, %{printer_pid: pid}}
  end

  defp assert_printer_status(expected_status) do
    %{status: actual_status} = :sys.get_state(PrinterServer)

    assert expected_status == actual_status
  end

  describe "Printer.connect/2" do
    test "it connects when there is no connection", %{printer_pid: printer_pid} do
      assert_printer_status(:disconnected)

      {:ok, connection} = Overridable.new()

      assert Printer.connect(connection) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, _connection}}

      assert_printer_status(:connected)
    end

    test "it overrides the exisiting connection when the option is given", %{
      printer_pid: printer_pid
    } do
      {:ok, connection} = Overridable.new()

      assert Printer.connect(connection, override: true) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, ^connection}}

      assert_printer_status(:connected)

      {:ok, connection2} = Overridable.new()

      assert Printer.connect(connection, override: true) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, ^connection2}}

      assert_printer_status(:connected)
    end

    test "failing overrides lead to a disconnected state", %{
      printer_pid: printer_pid
    } do
      {:ok, connection} = Overridable.new()

      assert Printer.connect(connection) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, ^connection}}

      assert assert_printer_status(:connected)

      {:ok, bad_connection} = Overridable.new(open: fn _ -> {:error, "Boom!"} end)

      assert Printer.connect(bad_connection, override: true) == :ok
      PrinterServer |> :sys.get_state() |> IO.inspect(label: :state)

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open_failed, _connection_pid, "Boom!"}}

      assert assert_printer_status(:disconnected)
    end

    test "it returns an error when already connected", %{
      printer_pid: printer_pid
    } do
      {:ok, connection} = Overridable.new()

      assert Printer.connect(connection) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, ^connection}}

      assert assert_printer_status(:connected)

      assert Printer.connect(connection) == {:error, "Already connected"}
    end
  end

  # describe "Printer.disconnect" do
  #   test "it calls disconnect on the connection", %{connection: connection} do
  #     assert Printer.disconnect() == :ok
  #     assert InMemory.last_command(connection) == :disconnect
  #   end

  #   test "it changes the printer state to disconnected" do
  #     assert_printer_status(:connected)
  #     assert Printer.disconnect() == :ok
  #     assert_printer_status(:disconnected)
  #   end
  # end

  # describe "Printer.state/0" do
  #   test "it returns the current printer state" do
  #     assert {:ok, %State{}} = Printer.state()
  #   end
  # end

  # describe "Printer.extrude/1" do
  #   property "it sends a G1 command with extrude param", %{connection: connection} do
  #     check all amount <- Norm.gen(int_or_float()) do
  #       assert Printer.extrude(amount) == :ok
  #       assert InMemory.last_command(connection) == {:send, "G1 E#{amount}\n"}
  #     end
  #   end
  # end

  # describe "Printer.heat_hotend/1" do
  #   property "it sends a M104 command", %{connection: connection} do
  #     check all temperature <- Norm.gen(int_or_float()) do
  #       assert Printer.heat_hotend(temperature) == :ok
  #       assert InMemory.last_command(connection) == {:send, Gcode.m104(temperature)}
  #     end
  #   end
  # end

  # describe "Printer.head_bed/1" do
  #   property "it sends a M140 command", %{connection: connection} do
  #     check all temperature <- Norm.gen(int_or_float()) do
  #       assert Printer.heat_bed(temperature) == :ok
  #       assert InMemory.last_command(connection) == {:send, Gcode.m140(temperature)}
  #     end
  #   end
  # end

  # describe "Printer.start_temperature_report/1" do
  #   property "It sends a M155 command with an interval param", %{connection: connection} do
  #     check all interval <- Norm.gen(spec(is_integer() and (&(&1 >= 0)))) do
  #       assert Printer.start_temperature_report(interval) == :ok
  #       assert InMemory.last_command(connection) == {:send, Gcode.m155(interval)}
  #     end
  #   end
  # end

  # describe "Printer.stop_temperature_report/0" do
  #   property "It sends a M155 command with an interval of 0", %{connection: connection} do
  #     assert Printer.stop_temperature_report() == :ok
  #     assert InMemory.last_command(connection) == {:send, Gcode.m155(0)}
  #   end
  # end

  # @axes_combinations [
  #   ["X", "Y", "Z"],
  #   ["Y", "Z"],
  #   ["X", "Z"],
  #   ["X", "Y"],
  #   ["X"],
  #   ["Y"],
  #   ["Z"]
  # ]

  # describe "Printer.home/1" do
  #   test "it sends a G28 command with axes to home", %{connection: connection} do
  #     for axes <- @axes_combinations do
  #       assert Printer.home(axes) == :ok
  #       assert InMemory.last_command(connection) == {:send, Gcode.g28(axes)}
  #     end
  #   end

  #   test "you can't pass an empty list" do
  #     assert_raise Norm.MismatchError, fn -> Printer.home([]) end
  #   end
  # end

  # describe "Printer.move/1" do
  #   property "it sends a G0 command with axes params", %{connection: connection} do
  #     check all index <- integer(0..length(@axes_combinations)),
  #               keys = Enum.at(@axes_combinations, index),
  #               values <- list_of(integer(), length: length(keys)),
  #               axes = keys |> Enum.zip(values) |> Map.new() do
  #       assert Printer.move(axes) == :ok
  #       assert InMemory.last_command(connection) == {:send, Gcode.g0(axes)}
  #     end
  #   end

  #   test "you can't pass an empty list" do
  #     assert_raise Norm.MismatchError, fn -> Printer.move([]) end
  #   end
  # end
end
