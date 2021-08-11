defmodule Ui.Printer.Connection.Supervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_child(spec :: Supervisor.child_spec()) :: {:ok, pid()} | {:error, String.t()}
  def start_child(spec) do
    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:ok, pid, _info} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, term} ->
        {:error, "Unable to start child: #{inspect(term)}"}
    end
  end
end
