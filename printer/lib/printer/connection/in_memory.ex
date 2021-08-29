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
    with {:ok, pid} <- Agent.start_link(fn -> [] end) do
      {:ok,
       %__MODULE__{
         pid: pid
       }}
    end
  end

  def commands(%__MODULE__{
        pid: pid
      }) do
    Agent.get(pid, fn commands -> commands end)
  end

  defimpl Printer.Connection, for: Printer.Connection.InMemory do
    use Norms

    alias Printer.Connection.InMemory

    def connect(%InMemory{} = connection) do
      add_command(connection, :connect)

      {:ok, connection}
    end

    def disconnect(%InMemory{} = connection) do
      add_command(connection, :disconnect)
    end

    def send(%InMemory{} = connection, command) do
      add_command(connection, {:send, command})
    end

    def update(%InMemory{} = connection, message) do
      add_command(connection, {:update, message})

      {:ok, connection}
    end

    defp add_command(%InMemory{pid: pid}, command) do
      Agent.update(pid, fn commands -> [command | commands] end)
    end
  end
end
