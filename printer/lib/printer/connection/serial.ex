defmodule Printer.Connection.Serial do
  @moduledoc """
  Implements a `Printer.Connection` for USB Printers.
  """
  defstruct [:name, :pid, :speed]

  def new(args) do
    %__MODULE__{
      name: Keyword.fetch!(args, :name),
      pid: nil,
      speed: Keyword.fetch!(args, :speed)
    }
  end

  defimpl Printer.Connection.Protocol, for: Printer.Connection.Serial do
    alias Circuits.UART
    alias Printer.Connection.Serial

    def open(%Serial{pid: pid}) when is_pid(pid) do
      {:error, "Serial connection already open"}
    end

    def open(%Serial{name: name, speed: speed} = connection) do
      opts = [speed: speed, active: true, framing: {UART.Framing.Line, separator: "\n"}]

      with {:ok, pid} <- UART.start_link(),
           :ok <- UART.open(pid, name, opts) do
        {:ok, %{connection | pid: pid}}
      end
    end

    def close(%Serial{pid: nil}), do: :ok

    def close(%Serial{pid: pid}) when is_pid(pid) do
      if Process.alive?(pid) do
        UART.close(pid)
        UART.stop(pid)
      end

      :ok
    end

    def send(%Serial{pid: nil}, _command), do: :ok

    def send(%Serial{pid: pid}, command) do
      UART.write(pid, command)
    end

    def handle_message(%Serial{name: name} = connection, {:circuits_uart, name, data}) do
      {:ok, connection, data}
    end
  end
end
