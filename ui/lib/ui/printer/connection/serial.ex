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
    |> coll_of(kind: spec(is_list()), into: Map.new())
  end

  @contract new(args :: new_args()) :: s()
  def new(%{name: name, speed: speed}) do
    %__MODULE__{
      name: name,
      pid: nil,
      speed: speed
    }
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
