defmodule Ui.Printer do
  alias Ui.Printer.Server, as: PrinterServer

  def connect(connection) do
    GenServer.call(PrinterServer, {:connect, connection})
  end

  def send(command) do
    GenServer.call(PrinterServer, {:send, command})
  end
end
