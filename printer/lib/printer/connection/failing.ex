defmodule Printer.Connection.Failing do
  @moduledoc """
  A failing Printer Connection intended for use in testing.
  """
  defstruct []

  defimpl Printer.Connection.Protocol, for: Printer.Connection.Failing do
    def open(_connection) do
      {:error, "Failed"}
    end

    def close(_connection) do
      {:error, "Failed"}
    end

    def send(_connection, _message) do
      {:error, "Failed"}
    end

    def handle_response(_connection, _message) do
      {:error, "Failed"}
    end
  end
end
