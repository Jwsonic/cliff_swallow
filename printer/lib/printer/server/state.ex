defmodule Printer.Server.State do
  @moduledoc """
  State struct for `Printer.Server`.
  """
  defstruct [
    :connection_server,
    :print_job,
    :retry_count,
    :send_queue,
    :line_number,
    :previous_response,
    :status,
    :timeout_reference,
    :wait
  ]
end
