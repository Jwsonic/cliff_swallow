defmodule Printer.Server.Wait do
  @moduledoc """
  Logic around which commands a printer should wait for, and how long.
  """

  alias Printer.Server.Command

  @type t() :: %{pos_integer() => Command.t()}

  @spec new() :: t()
  def new, do: %{}

  @spec add(wait :: t(), command :: Command.t()) :: t()
  def add(wait, %Command{} = command) do
    Map.put(wait, command.line_number, command)
  end

  defp smallest_key(wait) do
    wait
    |> Map.keys()
    |> Enum.sort()
    |> List.first()
  end

  @spec peek(wait :: t()) :: Command.t() | :empty
  def peek(wait) do
    peek_key = smallest_key(wait)

    Map.get(wait, peek_key, :empty)
  end

  @spec remove_lowest(wait :: t()) :: wait :: t()
  def remove_lowest(wait) do
    to_delete = smallest_key(wait)

    Map.delete(wait, to_delete)
  end

  @spec remove(wait :: t(), line_number :: pos_integer()) ::
          {Command.t(), wait :: t()} | :not_found
  def remove(wait, line_number) do
    case Map.pop(wait, line_number) do
      {nil, ^wait} -> :not_found
      result -> result
    end
  end

  @spec timeout(command :: Command.t()) :: pos_integer()

  def timeout(%Command{command: "M190" <> _rest}), do: 3 * 60 * 1_000
  def timeout(%Command{command: "M109" <> _rest}), do: 3 * 60 * 1_000
  def timeout(_command), do: 5_000
end
