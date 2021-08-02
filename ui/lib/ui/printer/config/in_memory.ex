defmodule Ui.Printer.Config.InMemory do
  defstruct []

  defimpl Ui.Printer.Config, for: Ui.Printer.Config.InMemory do
    def connect(config), do: {:ok, config}
    def disconnect(_config), do: :ok
  end

  import Norm

  def s(), do: schema(%__MODULE__{})
end
