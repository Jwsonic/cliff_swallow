defmodule Printer do
  @moduledoc """
  API for the `Printer` application.
  """
  use Norms

  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  def connect(connection) do
    GenServer.call(PrinterServer, {:connect, connection})
  end

  def send(command) do
    GenServer.call(PrinterServer, {:send, command})
  end

  def move(args) do
    args
    |> Gcode.move()
    |> send()
  end

  @contract heat(temp :: int_or_float()) :: simple_result()
  def heat(temp) do
    send("M109 S#{temp}\n")
  end
end
