defmodule Printer.Server.State do
  @moduledoc """
  State struct for `Printer.Server`.
  """
  defstruct [
    :connection,
    :retry_count,
    :send_queue,
    :status,
    :timeout_reference,
    :wait
  ]
end
