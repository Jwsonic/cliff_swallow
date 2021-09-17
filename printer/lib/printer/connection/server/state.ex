defmodule Printer.Connection.Server.State do
  @moduledoc """
  State struct for Connection
  """
  defstruct [:connection, :printer_server]

  def new(params) do
    params = Map.new(params)

    Map.merge(%__MODULE__{}, params)
  end
end
