defmodule Printer.Connection.Failing do
  defstruct []

  defimpl Printer.Connection, for: Printer.Connection.Failing do
    def connect(_connection), do: {:error, "Failed"}
    def disconnect(_connection), do: :ok
    def send(_connection, _message), do: {:error, "Failed"}
    def update(_connection, _message), do: {:error, "Failed"}
  end
end
