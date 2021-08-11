defmodule Ui.Printer.Connection.Virtual.State do
  defstruct [:listener, :port, :reference]

  import Norm

  def s(),
    do:
      schema(%__MODULE__{
        listener: spec(is_pid),
        port: spec(is_pid),
        reference: spec(is_reference)
      })
end
