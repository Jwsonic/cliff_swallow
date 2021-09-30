defmodule Printer.Server.State do
  @moduledoc """
  State struct for `Printer.Server`.
  """
  defstruct [:connection, :send_queue, :status, :wait]
end
