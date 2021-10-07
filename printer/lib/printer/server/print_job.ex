defmodule Printer.Server.PrintJob do
  @moduledoc """
  Holds data for an ongoing print.
  next_command does next print command when q is empty

  """

  defstruct [
    :pid,
    :path,
    :start_time
  ]

  alias __MODULE__

  require Logger

  @type t() :: %PrintJob{}

  @spec new(path :: Path.t()) :: {:ok, print_job :: t()} | {:error, reason :: any()}
  def new(path) do
    with {:ok, pid} <- File.open(path, [:read]) do
      {:ok,
       %PrintJob{
         pid: pid,
         path: path,
         start_time: DateTime.utc_now()
       }}
    end
  end

  @spec next_command(print_job :: t()) :: {:ok, command :: String.t()} | :done
  def next_command(%PrintJob{pid: pid} = print_job) do
    pid
    |> IO.read(:line)
    |> process_read_result(print_job)
  end

  # ; prefixed lines are comments in gcode
  defp process_read_result(";" <> _rest, print_job) do
    next_command(print_job)
  end

  defp process_read_result(command, _print_job)
       when is_binary(command) do
    command = String.replace_trailing(command, "\n", "")
    {:ok, command}
  end

  defp process_read_result(other, _print_job) do
    Logger.info("Stopping print job due to #{inspect(other)}")

    :done
  end
end
