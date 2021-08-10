defmodule Ui.Printer.Logic do
  @moduledoc """
  Business logic for Printer.
  """

  def init(_args) do
    {:ok, :disconnected}
  end

  def update(state, _message) do
    {:noreply, state}
  end
end
