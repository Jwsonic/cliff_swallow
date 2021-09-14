defmodule Printer do
  @moduledoc """
  API for the `Printer` application.
  """
  use Norms

  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  @contract connect(connection :: any_(), opts :: coll_of(:override)) :: simple_result()
  def connect(connection, opts \\ []) do
    GenServer.call(PrinterServer, {:connect, connection, opts})
  end

  def disconnect do
    GenServer.call(PrinterServer, :disconnect)
  end

  defp send(command) do
    GenServer.call(PrinterServer, {:send, command})
  end

  def move(args) do
    args
    |> Gcode.g0()
    |> send()
  end

  @contract heat_hotend(temp :: int_or_float()) :: simple_result()
  def heat_hotend(temp) do
    temp
    |> Gcode.m109()
    |> send()
  end

  def extrude(amount) do
    [e: amount]
    |> Gcode.g1()
    |> send()
  end

  @contract start_temperature_report(interval :: spec(is_integer() and (&(&1 >= 0)))) ::
              simple_result()
  def start_temperature_report(interval) do
    interval
    |> Gcode.m155()
    |> send()
  end

  @contract stop_temperature_report() :: simple_result()
  def stop_temperature_report do
    0
    |> Gcode.m155()
    |> send()
  end

  # home
  # estop
  # print
  # heat bed
end
