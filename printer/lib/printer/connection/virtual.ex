defmodule Printer.Connection.Virtual do
  @moduledoc """
  Implements a `Printer.Connection` to OctoPrint's virtual printer plugin
  """
  defstruct [:port, :reference]

  def new do
    %__MODULE__{
      port: nil,
      reference: nil
    }
  end

  defimpl Printer.Connection.Protocol, for: Printer.Connection.Virtual do
    require Logger

    alias Printer.Connection.Virtual

    def open(%Virtual{port: port, reference: reference})
        when is_port(port) and is_reference(reference) do
      {:error, "Connection is already open"}
    end

    def open(%Virtual{
          port: nil,
          reference: nil
        }) do
      with {:ok, python} <- find_python(),
           {:ok, script} <- find_script() do
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
    end

    defp find_python do
      case System.find_executable("python3") do
        nil -> {:error, "Unable to find python3 executable in path"}
        path -> {:ok, path}
      end
    end

    defp find_script do
      with priv_dir when not is_tuple(priv_dir) <- :code.priv_dir(:printer),
           path <- Path.join(priv_dir, "server.py"),
           true <- File.exists?(path) do
        {:ok, path}
      else
        {:error, :bad_name} -> {:error, "Unable to find priv dir"}
        false -> {:error, "Unable to find script"}
      end
    end

    def close(%Virtual{port: port}) do
      if is_port(port) and Port.info(port) != nil do
        Port.close(port)
      end

      :ok
    end

    def send(%Virtual{port: port, reference: reference}, _message)
        when not is_port(port) or
               not is_reference(reference) do
      {:error, "Virtual printer not connected"}
    end

    def send(%Virtual{port: port}, message) do
      port
      |> Port.command(message, [])
      |> case do
        true -> :ok
        false -> {:error, "Failed to send #{message} to virtual printer."}
      end
    end

    def handle_message(%Virtual{port: port} = connection, {port, {:data, data}}) do
      {:ok, connection, data}
    end

    def handle_message(
          %Virtual{port: port, reference: reference},
          {:DOWN, reference, :port, port, reason}
        ) do
      {:closed, "#{inspect(reason)}"}
    end

    # Drop other messages for now
    def handle_message(connection, _message) do
      {:ok, connection}
    end
  end
end
