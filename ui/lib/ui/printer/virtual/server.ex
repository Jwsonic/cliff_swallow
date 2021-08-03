defmodule Ui.Printer.Virtual.Server do
  @moduledoc """
  Manages a 'virtual' printer from Octoprint.
  """
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    {:ok, %{reference: nil, port: nil}, {:continue, :start_port}}
  end

  def handle_continue(:start_port, _state) do
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

    {:noreply, %{port: port, reference: reference}}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    IO.inspect(data, label: :printer)

    {:noreply, state}
  end

  def handle_info(
        {:DOWN, reference, :port, port, reason},
        %{reference: reference, port: port} = state
      ) do
    Logger.warn("Port closed: #{reason}")

    {:stop, reason, state}
  end

  def handle_info(message, state) do
    IO.inspect(message, label: :message)

    {:noreply, state}
  end

  def send(command) do
    GenServer.call(__MODULE__, {:send, command})
  end

  def handle_call({:send, command}, _from, %{port: port} = state) when is_bitstring(command) do
    reply =
      port
      |> Port.command(command, [])
      |> case do
        true -> :ok
        false -> {:error, "Failed to send #{command} to virtual printer."}
      end

    {:reply, reply, state}
  end
end
