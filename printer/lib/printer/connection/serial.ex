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

  # defimpl Printer.Connection, for: Printer.Connection.Serial do

  #   alias Circuits.UART
  #   alias Printer.Connection.Serial

  #   @contract connect(connection :: Serial.s()) :: result(Serial.s(), any_())
  #   def connect(%Serial{pid: pid} = connection) when is_pid(pid) do
  #     {:ok, connection}
  #   end

  #   def connect(%Serial{name: name, speed: speed} = connection) do
  #     with {:ok, pid} <- UART.start_link(),
  #          :ok <-
  #            UART.open(pid, name,
  #              speed: speed,
  #              active: true,
  #              framing: {UART.Framing.Line, separator: "\n"}
  #            ) do
  #       {:ok, %{connection | pid: pid}}
  #     end
  #   end

  #   @contract disconnect(connection :: Serial.s()) :: :ok
  #   def disconnect(%Serial{pid: nil}), do: :ok

  #   def disconnect(%Serial{pid: pid}) when is_pid(pid) do
  #     if Process.alive?(pid) do
  #       UART.close(pid)
  #       UART.stop(pid)
  #     end

  #     :ok
  #   end

  #   @contract send(connection :: Serial.s(), command :: spec(is_binary())) :: simple_result()
  #   def send(%Serial{pid: nil}, _command), do: :ok

  #   def send(%Serial{pid: pid}, command) do
  #     UART.write(pid, command)
  #   end

  #   @contract update(connection :: Serial.s(), message :: any_()) :: result(Serial.s(), any_())
  #   def update(%Serial{name: name} = connection, {:circuits_uart, name, data}) do
  #     Process.send(self(), {:connection_data, data}, [])

  #     {:ok, connection}
  #   end

  #   def update(connection, _message) do
  #     {:ok, connection}
  #   end
  # end
end
