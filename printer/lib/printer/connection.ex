defmodule Printer.Connection do
  @moduledoc """
  Internal API for managing a Connection
  """

  use Norms

  alias Printer.Connection.Server

  @contract open(connection :: any_(), override? :: spec(is_boolean())) :: simple_result()
  def open(connection, override? \\ false) do
    GenServer.call(Server, {:open, connection, override?})
  end

  @contract close() :: simple_result()
  def close do
    GenServer.call(Server, :close)
  end

  @contract send(message :: any_()) :: simple_result()
  def send(message) do
    GenServer.call(Server, {:send, message})
  end
end
