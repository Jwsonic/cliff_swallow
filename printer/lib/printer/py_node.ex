defmodule Printer.PyNode do
  def start do
    python3 = "python3" |> System.find_executable() |> to_charlist()

    python_path = to_charlist("priv/python")

    {:ok, pid} = :python.start(python_path: python_path, python: python3)

    :python.call(pid, :example, :start_read, [self()])

    pid
  end

  def write(pid) do
    :python.call(pid, :example, :write, ['m105\n'])
  end

  def test do
    pid = start()

    :python.call(pid, :example, :write, ["m105\n"])
  end
end
