defmodule Printer.Connection.Overridable do
  @moduledoc """
  A Connection that allows for overridable methods
  """

  defstruct [:open, :close, :send, :handle_response]

  use Norms

  def new(args \\ []) do
    %__MODULE__{
      open: Keyword.get(args, :open, fn connection -> {:ok, connection} end),
      close: Keyword.get(args, :close, fn _ -> :ok end),
      send: Keyword.get(args, :send, fn _, _ -> :ok end),
      handle_response: Keyword.get(args, :handle_response, fn _, _ -> :ok end)
    }
  end

  defimpl Printer.Connection.Protocol, for: Printer.Connection.Overridable do
    def open(connection) do
      apply(connection.open, [connection])
    end

    def close(connection) do
      apply(connection.close, [connection])
    end

    def send(connection, message) do
      apply(connection.send, [connection, message])
    end

    def handle_response(connection, response) do
      apply(connection.handle_response, [connection, response])
    end
  end
end
