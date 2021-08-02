defmodule Ui.Printer do
  defstruct [:config, :status]

  import Norm

  alias Ui.Printer.Config.{InMemory, Serial, Virtual}

  @status one_of([
            :disconnected,
            :connecting,
            :connected,
            :wating,
            :printing
          ])

  @config one_of([
            InMemory.s(),
            Serial.s(),
            Virtual.s()
          ])

  def s do
    schema(%__MODULE__{
      config: @config,
      status: @status
    })
  end
end
