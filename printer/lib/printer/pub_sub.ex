defmodule Printer.PubSub do
  @moduledoc """
  Printer domain pubsub methods.
  """

  alias Phoenix.PubSub
  alias Printer.Status

  def child_spec(_args) do
    Phoenix.PubSub.child_spec(name: __MODULE__)
  end

  @printer_topic "printer"

  def broadcast(%Status{} = status) do
    PubSub.broadcast(__MODULE__, @printer_topic, status)
  end

  def subscribe do
    PubSub.subscribe(__MODULE__, @printer_topic)
  end

  def unsubscribe do
    PubSub.unsubscribe(__MODULE__, @printer_topic)
  end
end
