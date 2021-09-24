defmodule Printer do
  @moduledoc """
  API for the `Printer` application.
  """

  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  def connect(connection) do
    GenServer.call(PrinterServer, {:connect, connection})
  end

  def disconnect do
    GenServer.call(PrinterServer, :disconnect)
  end

  def send(command) do
    GenServer.call(PrinterServer, {:send, command})
  end

  def move(axes) do
    axes
    |> Gcode.g0()
    |> send()
  end

  def heat_hotend(temperature) do
    temperature
    |> Gcode.m104()
    |> send()
  end

  def heat_bed(temperature) do
    temperature
    |> Gcode.m140()
    |> send()
  end

  def extrude(amount) do
    %{"E" => amount}
    |> Gcode.g1()
    |> send()
  end

  def start_temperature_report(interval) do
    interval
    |> Gcode.m155()
    |> send()
  end

  def stop_temperature_report do
    0
    |> Gcode.m155()
    |> send()
  end

  def home(axes) do
    axes
    |> Gcode.g28()
    |> send()
  end

  def start_print(path) do
    with {:ok, _info} <- File.stat(path) do
      GenServer.call(PrinterServer, {:print_start, path})
    end
  end
end
