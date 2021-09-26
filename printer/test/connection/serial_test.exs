defmodule Printer.Connection.SerialTest do
  @moduledoc """
  Tests for the serial printer connection.
  """
  use ExUnit.Case, async: false

  alias Circuits.UART
  alias Printer.Connection.Protocol, as: ConnectionProtocol
  alias Printer.Connection.Serial

  setup_all do
    socat_bin = System.find_executable("socat")

    if socat_bin == nil do
      flunk("Please make sure you have socat installed.")
    end

    dir = System.tmp_dir!()
    write = Path.join(dir, "virtual-write")
    read = Path.join(dir, "virtual-read")

    port =
      Port.open(
        {:spawn_executable, socat_bin},
        args: [
          "pty,link=#{write},raw,echo=0",
          "pty,link=#{read},raw,echo=0"
        ]
      )

    {:os_pid, os_pid} = Port.info(port, :os_pid)

    on_exit(fn ->
      System.cmd("kill", ["-9", "#{os_pid}"])
    end)

    {:ok, read: read, write: write}
  end

  setup %{write: write} do
    connection = Serial.new(name: write, speed: 115_200)

    {:ok, %{connection: connection}}
  end

  defp assert_pid_alive(pid) do
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  describe "Serial.open/1" do
    test "it spawns serial printer connection", %{connection: connection} do
      {:ok, %{pid: pid}} = ConnectionProtocol.open(connection)

      assert_pid_alive(pid)
    end

    test "it returns an error if the connection is already open", %{connection: connection} do
      {:ok, connection} = ConnectionProtocol.open(connection)

      assert ConnectionProtocol.open(connection) == {:error, "Serial connection already open"}
    end

    test "it starts UART in active mode", %{connection: connection} do
      {:ok, %{pid: pid}} = ConnectionProtocol.open(connection)

      {_name, config} = UART.configuration(pid)

      assert Keyword.fetch!(config, :active) == true
    end
  end

  describe "Serial.close/1" do
    test "it closes a port if there's one open", %{connection: connection} do
      {:ok, connection} = ConnectionProtocol.open(connection)

      assert_pid_alive(connection.pid)

      assert ConnectionProtocol.close(connection) == :ok

      refute Process.alive?(connection.pid)
    end

    test "it does nothing if there's no port open", %{connection: connection} do
      assert connection.pid == nil

      assert ConnectionProtocol.close(connection) == :ok
    end
  end

  describe "Serial.send/2" do
    test "it sends the message to the serial port", %{connection: connection, read: read} do
      {:ok, connection} = ConnectionProtocol.open(connection)

      {:ok, pid} = UART.start_link()

      :ok = UART.open(pid, read, speed: 115_200, active: false)

      assert ConnectionProtocol.send(connection, "G10") == :ok

      assert UART.read(pid) == {:ok, "G10\n"}
    end
  end

  describe "Serial.handle_message/2" do
    test "it forwards serial messages as connection messages", %{
      connection: %{name: name} = connection
    } do
      {:ok, _connection, "test"} =
        ConnectionProtocol.handle_message(connection, {:circuits_uart, name, "test"})
    end
  end
end
