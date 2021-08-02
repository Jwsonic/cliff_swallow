defmodule Ui.Printer.Config.Virtual do
  defstruct []

  defimpl Ui.Printer.Config, for: Ui.Printer.Config.Virtual do
    def connect(config), do: {:ok, config}
    def disconnect(_config), do: :ok
  end

  import Norm

  def s(), do: schema(%__MODULE__{})
end
