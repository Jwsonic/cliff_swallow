defmodule Printer.Connection.Overridable do
  @moduledoc """
  A Connection that allows for overridable methods
  """

  defstruct [:open, :close, :send, :handle_message]

  @new_schema NimbleOptions.new!(
                open: [
                  type: {:fun, 1},
                  doc: "Function to call for Connection.Protocol.open/1"
                ],
                close: [
                  type: {:fun, 1},
                  doc: "Function to call for Connection.Protocol.close/1"
                ],
                send: [
                  type: {:fun, 2},
                  doc: "Function to call for Connection.Protocol.send/2"
                ],
                handle_message: [
                  type: {:fun, 2},
                  doc: "Function to call for Connection.Protocol.handle_message/2"
                ]
              )

  @doc """
  Create a new `Printer.Connection.Overridable`.

  Supported args: #{NimbleOptions.docs(@new_schema)}
  """
  def new(args \\ []) do
    case NimbleOptions.validate(args, @new_schema) do
      {:ok, args} ->
        {:ok,
         %__MODULE__{
           open: Keyword.get(args, :open, fn connection -> {:ok, connection} end),
           close: Keyword.get(args, :close, fn _connection -> :ok end),
           send: Keyword.get(args, :send, fn _connection, _message -> :ok end),
           handle_message:
             Keyword.get(args, :handle_message, fn connection, _message -> {:ok, connection} end)
         }}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
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

    def handle_message(connection, message) do
      apply(connection.handle_message, [connection, message])
    end
  end
end
