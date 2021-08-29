defmodule Printer.PubSub do
  @moduledoc """
  Printer domain pubsub methods.
  """

  alias Phoenix.PubSub

  def child_spec(_args) do
    Phoenix.PubSub.child_spec(name: __MODULE__)
  end

  @topic_private "#{to_string(__MODULE__)}/private"
  @topic_public "#{to_string(__MODULE__)}/public"

  def broadcast_private(message) do
    PubSub.broadcast(__MODULE__, @topic_private, message)
  end

  def broadcast_public(message) do
    PubSub.broadcast(__MODULE__, @topic_public, message)
  end

  def subscribe_private do
    PubSub.subscribe(__MODULE__, @topic_private)
  end

  def subscribe_public do
    PubSub.subscribe(__MODULE__, @topic_public)
  end
end
