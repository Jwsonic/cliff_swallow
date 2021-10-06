defmodule Printer.Server.ResponseParser do
  @moduledoc """
  Printer response parser
  """

  import NimbleParsec

  ok =
    string("ok")
    |> eos()

  start =
    string("start")
    |> eos()

  defp parse_float(_rest, args, context, _line, _offset) do
    args
    |> Enum.reverse()
    |> Enum.join()
    |> Float.parse()
    |> case do
      {float, _rest} -> {[float], context}
      :error -> {:error, "#{inspect(args)} is not a float"}
    end
  end

  float =
    integer(min: 1)
    |> string(".")
    |> integer(min: 1)
    |> post_traverse({:parse_float, []})

  extruder_temperature =
    ignore(string("T:"))
    |> concat(float)
    |> unwrap_and_tag(:extruder_temperature)

  bed_temperature =
    ignore(string("B:"))
    |> concat(float)
    |> unwrap_and_tag(:bed_temperature)

  ok_temperature =
    ignore(string("ok "))
    |> concat(extruder_temperature)
    |> eventually(bed_temperature)

  error =
    ignore(string("Error:"))
    |> utf8_string([], min: 1)
    |> eos()
    |> unwrap_and_tag(:error)

  resend =
    ignore(
      choice([
        string("rs "),
        string("Resend ")
      ])
    )
    |> integer(min: 1)
    |> unwrap_and_tag(:resend)

  busy =
    ignore(string("busy:"))
    |> ignore(optional(string(" ")))
    |> utf8_string([], min: 1)
    |> eos()
    |> unwrap_and_tag(:busy)

  defparsecp(
    :do_parse,
    choice([
      ok,
      start,
      extruder_temperature,
      bed_temperature,
      ok_temperature,
      resend,
      error,
      busy
    ])
  )

  @spec parse(data :: String.t()) ::
          :ok
          | :start
          | {:resend, line :: pos_integer()}
          | {:error, error :: String.t()}
          | {:ok}
  def parse(data) do
    case do_parse(data) do
      {:ok, ["ok"], _, _, _, _} -> :ok
      {:ok, ["start"], _, _, _, _} -> :start
      {:ok, [{:resend, line}], _, _, _, _} -> {:resend, line}
      {:ok, [{:error, error}], _, _, _, _} -> {:error, error}
      {:ok, [{:busy, reason}], _, _, _, _} -> {:busy, reason}
      {:ok, data, _, _, _, _} -> {:temperature, Map.new(data)}
      {:error, error, _, _, _, _} -> {:parse_error, error}
    end
  end
end
