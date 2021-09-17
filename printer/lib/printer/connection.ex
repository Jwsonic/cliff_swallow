defmodule Printer.Connection do
  @moduledoc """
  Internal API for managing a Connection
  """

  use Norms

  alias Printer.Connection.DynamicSupervisor, as: ConnectionSupervisor

  @contract open(
              connection :: any_(),
              opts ::
                coll_of(
                  one_of([
                    {:override, spec(is_boolean())},
                    {:printer_server, spec(is_pid())}
                  ])
                )
            ) :: result(spec(is_pid()))
  def open(connection, opts \\ []) do
    override? = Keyword.get(opts, :override, false)
    supervisor_opts = Keyword.take(opts, [:printer_server])

    with {:ok, pid} <- ConnectionSupervisor.start_connection_server(supervisor_opts),
         :ok <- GenServer.call(pid, {:open, connection, override?}) do
      {:ok, pid}
    end
  end

  @contract close(connection :: spec(is_pid())) :: simple_result()
  def close(connection) do
    GenServer.call(connection, :close)
  end

  @contract send(connection :: spec(is_pid()), message :: any_()) :: simple_result()
  def send(connection, message) do
    GenServer.call(connection, {:send, message})
  end
end
