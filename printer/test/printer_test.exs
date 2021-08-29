defmodule PrinterTest do
  use ExUnit.Case
  doctest Printer

  test "greets the world" do
    assert Printer.hello() == :world
  end
end
