defmodule Ui.Printer.Connection.SerialTest do
  @moduledoc """
  Tests for the serial printer connection.
  """
  use ExUnit.Case, async: false

  alias Circuits.UART
  alias Ui.Printer.Connection
  alias Ui.Printer.Connection.Serial

  @dev0 "/dev/tnt0"
  @dev1 "/dev/tnt1"

  @moduletag :tty0tty_required

  setup context do
    unless File.exists?(@dev0) && File.exists?(@dev1) do
      flunk(
        "Please make sure tty0tty(https://github.com/freemed/tty0tty) is installed before running this test."
      )
    end

    connection = Serial.new(name: @dev0, speed: 9600)

    connection =
      case context[:no_connect] do
        true ->
          connection

        _ ->
          {:ok, connection} = Connection.connect(connection)

          on_exit(fn -> Connection.disconnect(connection) end)

          connection
      end

    {:ok, %{connection: connection}}
  end

  defp assert_pid_alive(pid) do
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  describe "Serial.connect/1" do
    @tag :no_connect
    test "it spawns serial printer connection", %{connection: connection} do
      assert connection.pid == nil

      {:ok, connection} = Connection.connect(connection)

      assert_pid_alive(connection.pid)

      Connection.disconnect(connection)
    end

    test "it does nothing if a port is already open", %{connection: connection} do
      assert_pid_alive(connection.pid)

      {:ok, connection2} = Connection.connect(connection)

      assert connection == connection2
      assert_pid_alive(connection2.pid)
    end

    test "it starts UART in active mode" do
      {:ok, pid} = UART.start_link()

      :ok = UART.open(pid, @dev1, speed: 9600, active: false)

      UART.write(pid, "ok\n")

      assert_receive {:circuits_uart, @dev0, "ok"}
    end
  end

  describe "Serial.disconnect/1" do
    @tag :no_connect
    test "it closes a port if there's one open", %{connection: connection} do
      {:ok, connection} = Connection.connect(connection)

      assert_pid_alive(connection.pid)

      Connection.disconnect(connection)

      refute Process.alive?(connection.pid)
    end

    @tag :no_connect
    test "it does nothing if there's no port open", %{connection: connection} do
      assert connection.pid == nil

      assert Connection.disconnect(connection) == :ok
    end
  end

  describe "Serial.send/2" do
    test "it sends the message to the serial port", %{connection: connection} do
      {:ok, pid} = UART.start_link()

      :ok = UART.open(pid, @dev1, speed: 9600, active: false)

      Connection.send(connection, "G10")

      assert UART.read(pid) == {:ok, "G10\n"}
    end
  end

  describe "Serial.update/2" do
    test "it forwards pserial messages as connection messages", %{
      connection: %{name: name} = connection
    } do
      {:ok, _connection} = Connection.update(connection, {:circuits_uart, name, "test"})

      assert_receive {:connection_data, "test"}
    end

    test "it ignores other messages", %{connection: connection} do
      assert {:ok, connection} == Connection.update(connection, :yo)
    end
  end
end
