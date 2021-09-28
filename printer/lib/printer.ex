defmodule Printer do
  @moduledoc """
  API for the `Printer` application.
  """

  alias Printer.Gcode
  alias Printer.Server, as: PrinterServer

  @schema_connect_opts [
    override: [
      type: :boolean,
      default: false,
      doc: "If true is passed, it will override any existing `Printer.Connection`"
    ]
  ]

  @doc """
  Sets the `Printer`'s current connection.

  Available opts: #{NimbleOptions.docs(@schema_connect_opts)}
  """

  def connect(connection, opts \\ []) do
    with {:ok, opts} <- NimbleOptions.validate(opts, @schema_connect_opts) do
      override? = Keyword.get(opts, :override)

      GenServer.call(PrinterServer, {:connect, connection, override?})
    end
  end

  def disconnect do
    GenServer.call(PrinterServer, :disconnect)
  end

  def send(command) do
    GenServer.call(PrinterServer, {:send, command})
  end

  def move(axes) do
    case Gcode.g0(axes) do
      "G0 \n" -> {:error, "You must provide at least one axis of movement"}
      command -> send(command)
    end
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

  def home(axes \\ ["X", "Y", "Z"]) do
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
