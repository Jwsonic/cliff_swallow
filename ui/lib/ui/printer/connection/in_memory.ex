defmodule Ui.Printer.Connection.InMemory do
  @moduledoc """
  Implements a `Ui.Printer.Connection` that uses a function to emulate a `Ui.Printer`.
  """
  defstruct []

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.InMemory do
    def connect(config), do: {:ok, config}
    def disconnect(_config), do: :ok
  end

  import Norm

  def s do
    schema(%__MODULE__{})
  end
end
