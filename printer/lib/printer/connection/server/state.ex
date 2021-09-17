defmodule Printer.Connection.Server.State do
  @moduledoc """
  State struct for Connection
  """
  defstruct [:connection, :printer_server]

  use Norms

  def s do
    schema(%__MODULE__{
      connection: any_(),
      printer_server: one_of([spec(is_pid()), spec(is_atom())])
    })
  end

  @contract new(printer_server :: one_of([spec(is_pid()), spec(is_atom())])) :: s()
  def new(printer_server) do
    %__MODULE__{
      connection: nil,
      printer_server: printer_server
    }
  end

  @contract update(state :: s(), updates :: spec(is_map())) :: s()
  def update(%__MODULE__{} = state, updates) do
    Map.merge(state, updates)
  end
end
