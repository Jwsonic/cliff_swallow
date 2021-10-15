defmodule Printer.Server.ResponseParserTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Printer.Server.ResponseParser

  describe "parse/2" do
    test "parses ok" do
      assert ResponseParser.parse("ok") == :ok
    end

    test "parses start" do
      assert ResponseParser.parse("start") == :start
    end

    test "parses a temp" do
      assert ResponseParser.parse("T:540.14") ==
               {:ok, %{extruder_temperature: 540.14}}
    end

    test "parses a full temp line" do
      assert ResponseParser.parse("T:20.34 /0.00 B:42.47 /50.00 @:0 B@:127 W:?") ==
               {:ok, %{bed_temperature: 42.47, extruder_temperature: 20.34}}

      assert ResponseParser.parse(" T:21.25 /0.00 B:28.21 /0.00 @:0 B@:0") ==
               {:ok, %{bed_temperature: 28.21, extruder_temperature: 21.25}}
    end

    test "parses an ok temp" do
      assert ResponseParser.parse("ok T:75.30/ 0.00 B:21.30/ 0.00 @:64") ==
               {:ok,
                %{
                  extruder_temperature: 75.3,
                  bed_temperature: 21.3
                }}
    end

    test "parses resend" do
      assert ResponseParser.parse("Resend:100") ==
               {:resend, 100}

      assert ResponseParser.parse("Resend: 200") ==
               {:resend, 200}
    end

    test "parses errors" do
      assert ResponseParser.parse("Error:checksum mismatch, Last Line: 66555") ==
               {:error, "checksum mismatch, Last Line: 66555"}
    end

    test "parses busy" do
      assert ResponseParser.parse("busy: processing") ==
               {:busy, "processing"}
    end

    test "parse errors are tagged with :parse_error" do
      assert {:parse_error, _reason} =
               ResponseParser.parse("parse errors are tagged with :parse_error")
    end
  end
end
