defmodule Ui.Printer.Connection.InMemory do
  defstruct []

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.InMemory do
    def connect(config), do: {:ok, config}
    def disconnect(_config), do: :ok
  end

  import Norm

  def s(), do: schema(%__MODULE__{})
end
