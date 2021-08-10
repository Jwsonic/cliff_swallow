defmodule Ui.Printer.Server do
  @moduledoc """
  GenServer responsible for keeping track of the current printer status.
  """

  use GenServer

  alias Ui.Printer.Logic

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    state = Logic.init(args)

    {:ok, state}
  end

  def handle_info(message, state) do
    Logic.update(state, message)
  end
end
