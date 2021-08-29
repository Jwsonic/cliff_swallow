defmodule Printer.State do
  @moduledoc """
  State struct for the Printer domain
  """
  defstruct [:connection, :status]

  use Norms

  def s do
    schema(%__MODULE__{
      connection: spec(fn _ -> true end),
      status:
        one_of([
          :disconnected,
          :connecting,
          :connected,
          :wating,
          :printing
        ])
    })
  end

  def new do
    %__MODULE__{
      connection: nil,
      status: :disconnected
    }
  end
end
