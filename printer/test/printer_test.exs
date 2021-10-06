defmodule PrinterTest do
  @moduledoc """
  Tests for the virtual printer connection.
  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Printer.Connection.{InMemory, Overridable}
  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  @moduletag capture_log: true

  setup do
    Printer.reset()

    on_exit(fn -> Printer.reset() end)

    printer_pid = Process.whereis(PrinterServer)

    :erlang.trace(printer_pid, true, [:receive])

    {:ok, connection} = InMemory.start_link()

    assert Printer.connect(connection) == :ok

    assert_receive {:trace, ^printer_pid, :receive,
                    {:connection_open, _connection_pid, ^connection}}

    assert_printer_status(:connected)

    {:ok, %{connection: connection, printer_pid: printer_pid}}
  end

  defp assert_printer_status(expected_status) do
    %{status: actual_status} = :sys.get_state(PrinterServer)

    assert expected_status == actual_status
  end

  defp reset_printer(%{connection: connection, printer_pid: printer_pid}) do
    Printer.reset()
    Printer.connect(connection)

    assert_receive {:trace, ^printer_pid, :receive,
                    {:connection_open, _connection_pid, ^connection}}

    assert_printer_status(:connected)
  end

  describe "Printer.connect/2" do
    test "it connects when there is no connection", %{printer_pid: printer_pid} do
      Printer.reset()

      assert_printer_status(:disconnected)

      {:ok, connection} = InMemory.start_link()

      assert Printer.connect(connection) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, _connection}}

      assert InMemory.last_message(connection) == :open

      assert_printer_status(:connected)
    end

    test "it overrides the exisiting connection when the option is given", %{
      printer_pid: printer_pid
    } do
      assert_printer_status(:connected)

      {:ok, connection} = InMemory.start_link()

      assert Printer.connect(connection, override: true) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open, _connection_pid, ^connection}}

      assert InMemory.last_message(connection) == :open

      assert_printer_status(:connected)
    end

    test "a failing override leads to a disconnected state", %{
      printer_pid: printer_pid
    } do
      assert assert_printer_status(:connected)

      {:ok, bad_connection} = Overridable.new(open: fn _ -> {:error, "Boom!"} end)

      assert Printer.connect(bad_connection, override: true) == :ok

      assert_receive {:trace, ^printer_pid, :receive,
                      {:connection_open_failed, _connection_pid, "Boom!"}}

      assert assert_printer_status(:disconnected)
    end

    test "it returns an error when already connected" do
      assert assert_printer_status(:connected)

      {:ok, connection} = Overridable.new()

      assert Printer.connect(connection) == {:error, "Already connected"}
    end
  end

  describe "Printer.disconnect/1" do
    test "it calls close on the connection",
         %{connection: connection} do
      assert assert_printer_status(:connected)

      assert Printer.disconnect() == :ok

      assert InMemory.last_message(connection) == :close

      assert_printer_status(:disconnected)
    end
  end

  describe "Printer.extrude/1" do
    property "it sends a G1 command with extrude param",
             %{
               connection: connection
             } = context do
      check all amount <- positive_integer() do
        reset_printer(context)

        assert Printer.extrude(amount) == :ok

        assert InMemory.last_message(connection) ==
                 {:send, Gcode.g1(%{"E" => amount})}
      end
    end
  end

  describe "Printer.heat_hotend/1" do
    property "it sends a M104 command",
             %{
               connection: connection
             } = context do
      check all amount <- positive_integer() do
        reset_printer(context)
        assert Printer.heat_hotend(amount) == :ok

        assert InMemory.last_message(connection) ==
                 {:send, Gcode.m104(amount)}
      end
    end
  end

  describe "Printer.head_bed/1" do
    property "it sends a M140 command",
             %{
               connection: connection
             } = context do
      check all amount <- positive_integer() do
        reset_printer(context)
        assert Printer.heat_bed(amount) == :ok

        assert InMemory.last_message(connection) ==
                 {:send, Gcode.m140(amount)}
      end
    end
  end

  describe "Printer.start_temperature_report/1" do
    property "sends a M155 command with an interval param",
             %{
               connection: connection
             } = context do
      check all interval <- positive_integer() do
        reset_printer(context)

        assert Printer.start_temperature_report(interval) == :ok

        assert InMemory.last_message(connection) ==
                 {:send, Gcode.m155(interval)}
      end
    end
  end

  describe "Printer.stop_temperature_report/0" do
    test "sends a M155 command with an interval of 0", %{
      connection: connection
    } do
      assert Printer.stop_temperature_report() == :ok

      assert InMemory.last_message(connection) ==
               {:send, Gcode.m155(0)}
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
    test "it sends a G28 command with axes to home",
         %{
           connection: connection
         } = context do
      for axes <- @axes_combinations do
        reset_printer(context)

        assert Printer.home(axes) == :ok

        assert InMemory.last_message(connection) == {:send, Gcode.g28(axes)}
      end
    end
  end

  describe "Printer.move/1" do
    property "it sends a G0 command with axes params",
             %{
               connection: connection
             } = context do
      check all index <- integer(0..length(@axes_combinations)),
                keys = Enum.at(@axes_combinations, index),
                values <- list_of(integer(), length: length(keys)),
                axes = keys |> Enum.zip(values) |> Map.new() do
        reset_printer(context)

        assert Printer.move(axes) == :ok

        assert InMemory.last_message(connection) == {:send, Gcode.g0(axes)}
      end
    end

    test "you can't pass an empty list" do
      assert Printer.move(%{}) == {:error, "You must provide at least one axis of movement"}
    end
  end
end
