defmodule Ui.Printer.Connection.InMemory do
  @moduledoc """
  Implements a `Ui.Printer.Connection` that uses a function to emulate a `Ui.Printer`.
  """
  defstruct [:connect, :disconnect, :send, :update, :state]

  use Norms

  def s do
    schema(%__MODULE__{
      connect: fun_with_arity(1),
      disconnect: fun_with_arity(1),
      send: fun_with_arity(2),
      update: fun_with_arity(2),
      state: any_()
    })
  end

  def new(params) when is_list(params) do
    %__MODULE__{
      connect: Keyword.get(params, :connect, fn c -> {:ok, c} end),
      disconnect: Keyword.get(params, :disconnect, fn _ -> :ok end),
      send: Keyword.get(params, :send, fn _c, _m -> :ok end),
      update: Keyword.get(params, :update, fn c, _ -> {:ok, c} end),
      state: nil
    }
  end

  defimpl Ui.Printer.Connection, for: Ui.Printer.Connection.InMemory do
    use Norms

    alias Ui.Printer.Connection.InMemory

    @contract connect(connection :: InMemory.s()) :: result(InMemory.s())
    def connect(%InMemory{connect: connect} = connection) do
      connect.(connection)
    end

    @contract disconnect(connection :: InMemory.s()) :: :ok
    def disconnect(%InMemory{disconnect: disconnect} = connection) do
      disconnect.(connection)
    end

    @contract send(connection :: InMemory.s(), command :: spec(is_binary())) :: simple_result()
    def send(%InMemory{send: send} = connection, command) do
      send.(connection, command)
    end

    @contract update(connection :: InMemory.s(), message :: any_()) :: result(InMemory.s())
    def update(%InMemory{update: update} = connection, message) do
      update.(connection, message)
    end
  end
end
