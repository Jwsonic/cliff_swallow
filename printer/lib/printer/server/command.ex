defmodule Printer.Server.Command do
  defstruct [
    :command,
    :line_number,
    :checksum
  ]

  alias __MODULE__

  @type t() :: %Command{}

  @spec new(command :: String.t(), line_number :: pos_integer()) :: t()
  def new(command, line_number)
      when is_binary(command) and
             is_integer(line_number) and
             line_number > 0 do
    checksum =
      "N#{line_number} #{command} "
      |> to_charlist()
      |> Enum.reduce(0, &Bitwise.bxor/2)

    %Command{
      command: command,
      line_number: line_number,
      checksum: checksum
    }
  end

  defimpl String.Chars, for: Printer.Server.Command do
    alias Printer.Server.Command

    def to_string(%Command{} = command) do
      "N#{command.line_number} #{command.command} *#{command.checksum}\n"
    end
  end
end
