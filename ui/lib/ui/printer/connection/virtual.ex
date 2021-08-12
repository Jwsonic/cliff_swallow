defmodule Ui.Printer.Connection.Virtual do
  defstruct [:port, :reference]

  import Norm

  def s do
    schema(%__MODULE__{
      port:
        one_of([
          spec(is_port()),
          spec(is_nil())
        ]),
      reference:
        one_of([
          spec(is_reference()),
          spec(is_nil())
        ])
    })
  end

  def new do
    %__MODULE__{
      port: nil,
      reference: nil
    }
  end

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.Virtual do
    use Norm

    require Logger

    alias Ui.Printer.Connection.Virtual

    @contract connect(connection :: Virtual.s()) ::
                one_of([
                  {:ok, Virtual.s()},
                  {:error, spec(is_binary())}
                ])

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
      Port.close(port)

      :ok
    end

    @contract send(connection :: Virtual.s(), command :: spec(is_binary())) ::
                one_of([
                  :ok,
                  {:error, spec(is_binary())}
                ])

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

    @contract update(connection :: Virtual.s(), message :: spec(fn _ -> true end)) ::
                one_of([
                  {:ok, Virtual.s()},
                  {:error, spec(is_binary())}
                ])
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
