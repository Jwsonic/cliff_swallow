defmodule Printer.Connection.DynamicSupervisor do
  @moduledoc """
  `Printer.Connection` Supervisor
  """
  use DynamicSupervisor

  alias Printer.Connection.Server, as: ConnectionServer

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @start_connection_server_schema NimbleOptions.new!(
                                    connection: [
                                      required: true,
                                      doc: "The type of connection to start"
                                    ],
                                    printer_server: [
                                      type: {:or, [:atom, :pid]},
                                      required: true,
                                      doc: "The process to send connection messages to."
                                    ]
                                  )

  @doc """
  Starts a process to manage a `Printer.Connection`.

  Supported args:\n#{NimbleOptions.docs(@start_connection_server_schema)}
  """
  def start_connection_server(args \\ []) do
    case NimbleOptions.validate(args, @start_connection_server_schema) do
      {:ok, args} ->
        spec = %{
          id: ConnectionServer,
          start: {ConnectionServer, :start_link, [args]},
          restart: :transient
        }

        DynamicSupervisor.start_child(__MODULE__, spec)

      {:error, %NimbleOptions.ValidationError{} = error} ->
        {:error, Exception.message(error)}
    end
  end
end
