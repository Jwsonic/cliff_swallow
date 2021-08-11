defmodule Ui.Printer.Connection.Virtual do
  defstruct [:pid]

  import Norm

  def s(),
    do: schema(%__MODULE__{pid: spec(is_pid())})

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.Virtual do
    alias Ui.Printer.Connection.Supervisor, as: ConnectionSupervisor
    alias Ui.Printer.Connection.Virtual
    alias Ui.Printer.Connection.Virtual.Server, as: VirtualServer

    def connect(args) do
      with {:ok, pid} <- ConnectionSupervisor.start_link({VirtualServer, args}) do
        {:ok, %Virtual{pid: pid}}
      end
    end

    def disconnect(_config), do: :ok

    def send(%Virtual{pid: pid}, command) do
      GenServer.call(pid, {:send, command})
    end
  end
end
