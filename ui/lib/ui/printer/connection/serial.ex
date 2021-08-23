defmodule Ui.Printer.Connection.Serial do
  @moduledoc """
  Implements a `Ui.Printer.Connection` for USB Printers.
  """
  defstruct [:name, :pid, :speed]

  use Norms

  def s do
    schema(%__MODULE__{
      name: spec(is_binary()),
      pid: allow_nil(spec(is_pid())),
      speed: spec(is_integer() and fn s -> s > 0 end)
    })
  end

  defp new_args do
    [
      {:name, spec(is_binary())},
      {:speed, spec(is_integer() and fn s -> s > 0 end)}
    ]
    |> one_of()
    |> coll_of(kind: &is_list/1)
  end

  @contract new(args :: new_args()) :: s()
  def new(args) do
    %__MODULE__{
      name: Keyword.fetch!(args, :name),
      pid: nil,
      speed: Keyword.fetch!(args, :speed)
    }
  end

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.Serial do
    use Norms

    alias Circuits.UART
    alias Ui.Printer.Connection.Serial

    @contract connect(connection :: Serial.s()) :: result(Serial.s())
    def connect(%Serial{pid: pid} = connection) when is_pid(pid) do
      {:ok, connection}
    end

    def connect(%Serial{name: name, speed: speed} = connection) do
      with {:ok, pid} <- UART.start_link(),
           :ok <-
             UART.open(pid, name,
               speed: speed,
               active: true,
               framing: {UART.Framing.Line, separator: "\n"}
             ) do
        {:ok, %{connection | pid: pid}}
      end
    end

    @contract disconnect(connection :: Serial.s()) :: :ok
    def disconnect(%Serial{pid: nil}), do: :ok

    def disconnect(%Serial{pid: pid}) when is_pid(pid) do
      if Process.alive?(pid) do
        UART.close(pid)
        UART.stop(pid)
      end

      :ok
    end

    @contract send(connection :: Serial.s(), command :: spec(is_binary())) :: simple_result()
    def send(%Serial{pid: nil}, _command), do: :ok

    def send(%Serial{pid: pid}, command) do
      UART.write(pid, command)
    end

    @contract update(connection :: Serial.s(), message :: any_()) :: result(Serial.s())
    def update(%Serial{name: name} = connection, {:circuits_uart, name, data}) do
      Process.send(self(), {:connection_data, data}, [])

      {:ok, connection}
    end

    def update(connection, _message) do
      {:ok, connection}
    end
  end
end
