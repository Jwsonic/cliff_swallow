defmodule Ui.Printer.Connection.Virtual do
  @moduledoc """
  Implements a `Ui.Printer.Connection` to OctoPrint's virtual printer plugin
  """
  defstruct [:port, :reference]

  use Norms

  def s do
    schema(%__MODULE__{
      port: allow_nil(spec(is_port())),
      reference: allow_nil(spec(is_reference()))
    })
  end

  def new do
    %__MODULE__{
      port: nil,
      reference: nil
    }
  end

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.Virtual do
    use Norms

    require Logger

    alias Ui.Printer.Connection.Virtual

    @contract connect(connection :: Virtual.s()) :: result(Virtual.s())
    def connect(%Virtual{port: port} = connection)
        when is_port(port) do
      {:ok, connection}
    end

    def connect(%Virtual{
          port: nil,
          reference: nil
        }) do
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

      {:ok,
       %Virtual{
         port: port,
         reference: reference
       }}
    end

    def connect(connection) do
      {:ok, connection}
    end

    @contract disconnect(connection :: Virtual.s()) :: :ok
    def disconnect(%Virtual{port: port}) do
      if is_port(port) and Port.info(port) != nil do
        Port.close(port)
      end

      :ok
    end

    @contract send(connection :: Virtual.s(), command :: spec(is_binary())) :: simple_result()
    def send(%Virtual{port: port, reference: reference}, _command)
        when not is_port(port) or
               not is_reference(reference) do
      {:error, "Virtual printer not connected"}
    end

    def send(%Virtual{port: port}, command) do
      port
      |> Port.command(command, [])
      |> case do
        true -> :ok
        false -> {:error, "Failed to send #{command} to virtual printer."}
      end
    end

    @contract update(connection :: Virtual.s(), message :: any_()) :: result(Virtual.s())
    def update(%Virtual{port: port} = connection, {port, {:data, data}}) do
      Process.send(self(), {:connection_data, data}, [])

      {:ok, connection}
    end

    def update(
          %Virtual{port: port, reference: reference},
          {:DOWN, reference, :port, port, reason}
        ) do
      {:error, "Port closed: #{inspect(reason)}"}
    end

    # Drop other messages for now
    def update(connection, _message) do
      {:ok, connection}
    end
  end
end
