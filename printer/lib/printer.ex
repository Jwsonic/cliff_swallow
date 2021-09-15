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

  @contract move(
              axes ::
                map_of(
                  spec(fn k -> k in ["X", "Y", "Z"] end),
                  int_or_float()
                )
            ) :: simple_result()
  def move(axes) do
    axes
    |> Gcode.g0()
    |> send()
  end

  @contract heat_hotend(temperature :: int_or_float()) :: simple_result()
  def heat_hotend(temperature) do
    temperature
    |> Gcode.m104()
    |> send()
  end

  @contract heat_bed(temperature :: int_or_float()) :: simple_result()
  def heat_bed(temperature) do
    temperature
    |> Gcode.m140()
    |> send()
  end

  @contract extrude(amount :: int_or_float()) :: simple_result()
  def extrude(amount) do
    %{"E" => amount}
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

  @contract home(
              axes ::
                coll_of(
                  spec(fn k -> k in ["X", "Y", "Z"] end),
                  distinct: true,
                  min_count: 1
                )
            ) :: simple_result()
  def home(axes) do
    axes
    |> Gcode.g28()
    |> send()
  end

  # print
  # heat bed
end
