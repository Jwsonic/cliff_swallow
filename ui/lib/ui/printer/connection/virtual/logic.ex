defmodule Ui.Printer.Connection.Virtual.Logic do
  use Norm

  require Logger

  alias Ui.Printer.Connection.Virtual.State

  @contract init(args :: coll_of([{:listener, spec(is_pid)}])) :: State.s()
  def init(args) do
    %State{
      listener: Keyword.fetch!(args, :listener)
    }
  end

  @contract start_port(state :: State.s()) :: State.s()
  def start_port(state) do
    python = System.find_executable("python3")
    priv_dir = :code.priv_dir(:ui)
    script = Path.join([priv_dir, "server.py"])

    port =
      Port.open({:spawn_executable, python}, [
        :binary,
        :nouse_stdio,
        {:packet, 4},
        {:args, ["-u", script]}
      ])

    reference = Port.monitor(port)

    %{state | reference: reference, port: port}
  end

  @contract port_data(state :: State.s(), data :: spec(is_binary)) :: :ok
  def port_data(%State{listener: listener}, data) do
    Process.send(listener, {:connection_data, data}, [])
  end

  def port_closed(_state, reason) do
    Logger.warn("Port closed: #{reason}")

    :ok
  end

  @contract send(state :: State.s(), command :: spec(is_binary)) ::
              one_of([:ok, {:error, spec(is_binary)}])
  def send(%State{port: port}, command) do
    port
    |> Port.command(command, [])
    |> case do
      true -> :ok
      false -> {:error, "Failed to send #{command} to virtual printer."}
    end
  end
end
