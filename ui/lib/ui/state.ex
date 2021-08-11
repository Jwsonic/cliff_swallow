defmodule Ui.Printer.State do
  defstruct [:connection, :status]

  import Norm

  alias Ui.Printer.Connection.{InMemory, Serial, Virtual}

  @status one_of([
            :disconnected,
            :connecting,
            :connected,
            :wating,
            :printing
          ])

  defp connection do
    one_of([
      InMemory.s(),
      Serial.s(),
      Virtual.s()
    ])
  end

  def s do
    schema(%__MODULE__{
      connection: connection(),
      status: @status
    })
  end
end
