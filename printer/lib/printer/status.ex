defmodule Printer.Status do
  @moduledoc """
  A struct shared with modules external to printer.
  Contains public information about the printer's status.
  """

  defstruct [
    :bed_temperature,
    :connection,
    :extruder_temperature,
    :status
  ]

  @type status() ::
          :connected
          | :connecting
          | :disconnected
          | :printing

  @type t() :: %__MODULE__{
          bed_temperature: pos_integer() | nil,
          connection: String.t() | nil,
          extruder_temperature: pos_integer() | nil,
          status: status()
        }

  @keys [
    :bed_temperature,
    :connection,
    :extruder_temperature,
    :status
  ]

  def update(%__MODULE__{} = status, changes)
      when is_map(changes) do
    changes = Map.take(changes, @keys)

    Map.merge(status, changes)
  end
end
