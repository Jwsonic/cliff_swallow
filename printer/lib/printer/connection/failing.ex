defmodule Printer.Connection.Failing do
  @moduledoc """
  A failing Printer Connection intended for use in testing.
  """
  defstruct []

  defimpl Printer.Connection, for: Printer.Connection.Failing do
    alias Printer.Connection.Failing

    def connect(%Failing{}) do
      {:error, "Failed"}
    end

    def disconnect(%Failing{}) do
      :ok
    end

    def send(%Failing{}, _message) do
      {:error, "Failed"}
    end

    def update(%Failing{}, _message) do
      {:error, "Failed"}
    end
  end
end
