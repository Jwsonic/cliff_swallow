defmodule Printer.Connection.InMemory do
  @moduledoc """
  A Printer Connection that stores commands in an Agent.
  """
  defstruct [:pid]

  use Agent
  use Norms

  def s do
    schema(%__MODULE__{
      pid: allow_nil(spec(is_pid()))
    })
  end

  def start do
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
    use Norms

    alias Printer.Connection.InMemory

    def open(%InMemory{} = connection) do
      add_history(connection, :open)

      {:ok, connection}
    end

    def close(%InMemory{} = connection) do
      add_history(connection, :close)
    end

    def send(%InMemory{} = connection, message) do
      add_history(connection, {:send, message})
    end

    def handle_response(%InMemory{} = connection, response) do
      add_history(connection, {:handle_response, response})

      response
    end

    defp add_history(%InMemory{pid: pid}, message) do
      if Process.alive?(pid) do
        Agent.update(pid, fn messages -> [message | messages] end)
      end
    end
  end
end
