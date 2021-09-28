defmodule PrinterTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Printer.Connection.{Echo, Overridable}
  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  @moduletag capture_log: true

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

  # Test helper that opens a printer connection and waits for it to be connected
  defp printer_connect(%{printer_pid: printer_pid}, connection \\ nil) do
    connection = connection || Echo.new()

    assert Printer.connect(connection) == :ok

    assert_receive {:trace, ^printer_pid, :receive,
                    {:connection_open, _connection_pid, ^connection}}

    assert_printer_status(:connected)
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

  describe "Printer.disconnect/1" do
    test "it calls close on the connection", context do
      printer_connect(context)

      assert Printer.disconnect() == :ok

      assert_receive {Echo, :close}

      assert_printer_status(:disconnected)
    end
  end

  describe "Printer.extrude/1" do
    property "it sends a G1 command with extrude param", context do
      printer_connect(context)

      check all amount <-
                  one_of([
                    integer(),
                    float()
                  ]) do
        assert Printer.extrude(amount) == :ok

        expected = Gcode.g1(%{"E" => amount})
        assert_receive {Echo, {:send, ^expected}}
      end
    end
  end

  describe "Printer.heat_hotend/1" do
    property "it sends a M104 command", context do
      printer_connect(context)

      check all temperature <-
                  one_of([
                    integer(),
                    float()
                  ]) do
        assert Printer.heat_hotend(temperature) == :ok

        expected = Gcode.m104(temperature)

        assert_receive {Echo, {:send, ^expected}}
      end
    end
  end

  describe "Printer.head_bed/1" do
    property "it sends a M140 command", context do
      printer_connect(context)

      check all temperature <-
                  one_of([
                    integer(),
                    float()
                  ]) do
        assert Printer.heat_bed(temperature) == :ok
        expected = Gcode.m140(temperature)

        assert_receive {Echo, {:send, ^expected}}
      end
    end
  end

  describe "Printer.start_temperature_report/1" do
    property "It sends a M155 command with an interval param", context do
      printer_connect(context)

      check all interval <- positive_integer() do
        assert Printer.start_temperature_report(interval) == :ok

        expected = Gcode.m155(interval)
        assert_receive {Echo, {:send, ^expected}}
      end
    end
  end

  describe "Printer.stop_temperature_report/0" do
    test "It sends a M155 command with an interval of 0", context do
      printer_connect(context)

      assert Printer.stop_temperature_report() == :ok

      expected = Gcode.m155(0)
      assert_receive {Echo, {:send, ^expected}}
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
    test "it sends a G28 command with axes to home", context do
      printer_connect(context)

      for axes <- @axes_combinations do
        assert Printer.home(axes) == :ok

        expected = Gcode.g28(axes)
        assert_receive {Echo, {:send, ^expected}}
      end
    end
  end

  describe "Printer.move/1" do
    property "it sends a G0 command with axes params", context do
      printer_connect(context)

      check all index <- integer(0..length(@axes_combinations)),
                keys = Enum.at(@axes_combinations, index),
                values <- list_of(integer(), length: length(keys)),
                axes = keys |> Enum.zip(values) |> Map.new() do
        assert Printer.move(axes) == :ok

        expected = Gcode.g0(axes)

        assert_receive {Echo, {:send, ^expected}}
      end
    end

    test "you can't pass an empty list", context do
      printer_connect(context)

      assert Printer.move(%{}) == {:error, "You must provide at least one axis of movement"}
    end
  end
end
