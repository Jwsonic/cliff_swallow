defmodule Ui.Printer.Connection.Serial do
  @moduledoc """
  Implements a `Ui.Printer.Connection` for USB Printers.
  """
  defstruct []

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.Serial do
    def connect(config), do: {:ok, config}
    def disconnect(_config), do: :ok
  end

  import Norm

  def s do
    schema(%__MODULE__{})
  end
end
