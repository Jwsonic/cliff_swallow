defmodule Printer.Connection.Virtual do
  @moduledoc """
  Implements a `Printer.Connection` to OctoPrint's virtual printer plugin
  """
  defstruct [:pid]

  def new do
    %__MODULE__{
      pid: nil
    }
  end

  defimpl Printer.Connection.Protocol, for: Printer.Connection.Virtual do
    require Logger

    alias Printer.Connection.Virtual

    def open(%Virtual{pid: pid})
        when is_pid(pid) do
      {:error, "Connection is already open"}
    end

    def open(%Virtual{
          pid: nil
        }) do
      with {:ok, python} <- find_python(),
           {:ok, python_path} <- find_python_path(),
           {:ok, pid} <-
             :python.start(
               python_path: python_path,
               python: python
             ),
           :ok <- :python.call(pid, :virtual, :start, [self()]) do
        Process.monitor(pid)

        {:ok, %Virtual{pid: pid}}
      end
    end

    defp find_python do
      case System.find_executable("python3") do
        nil -> {:error, "Unable to find python3 executable in path"}
        path -> {:ok, to_charlist(path)}
      end
    end

    defp find_python_path do
      case :code.priv_dir(:printer) do
        {:error, :bad_name} ->
          {:error, "Unable to find priv dir"}

        priv_dir ->
          path =
            priv_dir
            |> Path.join("python")
            |> to_charlist()

          {:ok, path}
      end
    end

    def close(%Virtual{pid: pid}) do
      if is_pid(pid) do
        Process.exit(pid, :kill)
      end

      :ok
    end

    def send(%Virtual{pid: pid}, _message)
        when not is_pid(pid) do
      {:error, "Virtual printer not connected"}
    end

    def send(%Virtual{pid: pid}, message) do
      :python.call(pid, :virtual, :write, [message])

      :ok
    end

    def handle_message(
          %Virtual{} = connection,
          {:virtual_printer, line}
        ) do
      {:ok, connection, line}
    end

    def handle_message(
          %Virtual{pid: pid},
          {:DOWN, _reference, :process, pid, reason}
        ) do
      {:closed, "#{inspect(reason)}"}
    end

    # Drop other messages for now
    def handle_message(connection, _message) do
      {:ok, connection}
    end
  end
end
