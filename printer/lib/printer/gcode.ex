defmodule Printer.Gcode do
  @moduledoc """
  Collection of functions for building G-code commands.
  More on G-code
  """

  @doc """
  Builds the command for a [linear move](https://marlinfw.org/docs/gcode/G000-G001.html).
  """
  def g0(axes) do
    params =
      ["X", "Y", "Z"]
      |> Enum.map(fn key -> {key, axes[key]} end)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map(fn {axis, value} -> "#{axis}#{value}" end)
      |> Enum.join(" ")

    "G0 #{params}"
  end

  @doc """
  Builds the command for a [linear move](https://marlinfw.org/docs/gcode/G000-G001.html).
  """
  def g1(axes) do
    params =
      ["E", "X", "Y", "Z"]
      |> Enum.map(fn key -> {key, axes[key]} end)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map(fn {axis, value} -> "#{axis}#{value}" end)
      |> Enum.join(" ")

    "G1 #{params}"
  end

  @doc """
  Builds a [home](https://marlinfw.org/docs/gcode/G028.html) command.
  """
  def g28(axes \\ []) do
    params =
      axes
      |> Enum.sort()
      |> Enum.join(" ")

    "G28 #{params}"
  end

  @doc """
  Builds a [set hotend temperature](https://marlinfw.org/docs/gcode/M104.html) command.
  """
  def m104(temperature), do: "M104 S#{temperature}"

  @doc """
  Builds a [wait for hotend](https://marlinfw.org/docs/gcode/M109.html) command.
  """
  def m109(temperature), do: "M109 S#{temperature}"

  @doc """
  Returns the [e-stop](https://marlinfw.org/docs/gcode/M112.html) command.
  """
  def m112, do: "M112"

  @doc """
  Builds a [set bed temperature](https://marlinfw.org/docs/gcode/M140.html) command.
  """
  def m140(temperature), do: "M140 S#{temperature}"

  @doc """
  Builds a [temperature auto report](https://marlinfw.org/docs/gcode/M155.html) command.
  """
  def m155(interval), do: "M155 S#{interval}"
end
