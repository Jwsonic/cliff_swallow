defmodule Printer.Gcode do
  "Collection of functions for building gcode commands"
  use Norms

  defp move_spec do
    [
      {:x, int_or_float()},
      {:y, int_or_float()},
      {:z, int_or_float()}
    ]
    |> one_of()
    |> coll_of()
  end

  @contract move(args :: move_spec()) :: spec(is_binary())
  def move(args) do
    args
    |> Enum.sort()
    |> Enum.reduce("G10 ", fn {axis, value}, acc ->
      axis =
        axis
        |> Atom.to_string()
        |> String.capitalize()

      "#{acc} #{axis}#{value}"
    end)
  end
end
