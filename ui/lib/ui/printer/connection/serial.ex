defmodule Ui.Printer.Connection.Serial do
  @moduledoc """
  Implements a `Ui.Printer.Connection` for USB Printers.
  """
  defstruct [:pid]

  use Norms

  def s do
    schema(%__MODULE__{
      pid: allow_nil(spec(is_pid()))
    })
  end

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.Serial do
    use Norms

    alias Ui.Printer.Connection.Serial

    @contract connect(connection :: Serial.s()) :: result(Serial.s())
    def connect(config) do
      {:ok, config}
    end

    @contract disconnect(connection :: Serial.s()) :: :ok
    def disconnect(_config), do: :ok

    @contract send(connection :: Serial.s(), command :: spec(is_binary())) :: simple_result()
    def send(_connection, _command), do: :ok

    @contract update(connection :: Serial.s(), message :: any_()) :: result(Serial.s())
    def update(connection, _message) do
      {:ok, connection}
    end
  end
end
