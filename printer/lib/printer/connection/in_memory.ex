defmodule Printer.Connection.InMemory do
  @moduledoc """
  A Printer Connection that stores commands in an Agent.
  """
  defstruct [:pid]

  use Agent

  def start_link do
    with {:ok, pid} <- Agent.start_link(fn -> [] end, timeout: 1_000) do
      {:ok,
       %__MODULE__{
         pid: pid
       }}
    end
  end

  def history(%__MODULE__{
        pid: pid
      }) do
    Agent.get(pid, fn messages -> messages end)
  end

  def last_message(%__MODULE__{
        pid: pid
      }) do
    Agent.get(pid, &List.first/1)
  end

  defimpl Printer.Connection.Protocol, for: Printer.Connection.InMemory do
    alias Printer.Connection.InMemory

    def open(%InMemory{} = connection) do
      add_history(connection, :open)

      {:ok, connection}
    end

    def close(%InMemory{} = connection) do
      add_history(connection, :close)

      :ok
    end

    def send(%InMemory{} = connection, message) do
      add_history(connection, {:send, message})

      :ok
    end

    def handle_message(%InMemory{} = connection, message) do
      add_history(connection, {:handle_message, message})

      {:ok, connection}
    end

    defp add_history(%InMemory{pid: pid}, message) do
      if Process.alive?(pid) do
        Agent.update(pid, fn messages -> [message | messages] end)
      end
    end
  end
end
