defmodule Printer.Gcode do
  @moduledoc """
  Collection of functions for building G-code commands.
  More on G-code
  """
  use Norms

  @doc """
  Builds the command for a [linear move](https://marlinfw.org/docs/gcode/G000-G001.html).
  """
  @contract g0(
              axes ::
                map_of(
                  spec(fn k -> k in ["X", "Y", "Z"] end),
                  int_or_float()
                )
            ) :: spec(is_binary())
  def g0(axes) do
    params =
      ["X", "Y", "Z"]
      |> Enum.map(fn key -> {key, axes[key]} end)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map(fn {axis, value} -> "#{axis}#{value}" end)
      |> Enum.join(" ")

    "G0 #{params}\n"
  end

  @doc """
  Builds the command for a [linear move](https://marlinfw.org/docs/gcode/G000-G001.html).
  """
  @contract g1(
              axes ::
                map_of(
                  spec(fn k -> k in ["E", "X", "Y", "Z"] end),
                  int_or_float()
                )
            ) :: spec(is_binary())
  def g1(axes) do
    params =
      ["E", "X", "Y", "Z"]
      |> Enum.map(fn key -> {key, axes[key]} end)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map(fn {axis, value} -> "#{axis}#{value}" end)
      |> Enum.join(" ")

    "G1 #{params}\n"
  end

  @doc """
  Builds a [home](https://marlinfw.org/docs/gcode/G028.html) command.
  """
  @contract g28(
              axes ::
                coll_of(
                  spec(fn k -> k in ["X", "Y", "Z"] end),
                  distinct: true,
                  min_count: 1
                )
            ) :: spec(is_binary())
  def g28(axes \\ []) do
    params =
      axes
      |> Enum.sort()
      |> Enum.join(" ")

    "G28 #{params}\n"
  end

  @doc """
  Builds a [set hotend temperature](https://marlinfw.org/docs/gcode/M104.html) command.
  """
  @contract m104(temperature :: int_or_float()) :: spec(is_binary())
  def m104(temperature), do: "M104 S#{temperature}\n"

  @doc """
  Builds a [wait for hotend](https://marlinfw.org/docs/gcode/M109.html) command.
  """
  @contract m109(temperature :: int_or_float()) :: spec(is_binary())
  def m109(temperature), do: "M109 S#{temperature}\n"

  @doc """
  Returns the [e-stop](https://marlinfw.org/docs/gcode/M112.html) command.
  """
  @contract m112() :: spec(is_binary())
  def m112, do: "M112\n"

  @doc """
  Builds a [set bed temperature](https://marlinfw.org/docs/gcode/M140.html) command.
  """
  @contract m140(temperature :: int_or_float()) :: spec(is_binary())
  def m140(temperature), do: "M140 S#{temperature}\n"

  @doc """
  Builds a [temperature auto report](https://marlinfw.org/docs/gcode/M155.html) command.
  """
  @contract m155(interval :: spec(is_integer() and (&(&1 >= 0)))) :: spec(is_binary())
  def m155(interval), do: "M155 S#{interval}\n"
end
