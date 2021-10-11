defmodule UiWeb.PrinterLive do
  use Phoenix.LiveView

  alias Printer.Status

  def render(assigns) do
    ~H"""
    <div>Current status: <%= @status.status %></div>
    <div>Bed Temperature: <%= @status.bed_temperature %></div>
    <div>Extruder Temperature: <%= @status.extruder_temperature %></div>
    <%= if @status.status == :disconnected do %>
    <button phx-click="connect">Connect</button>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, status} = Printer.status()

    if connected?(socket) do
      Printer.subscribe()
    end

    {:ok, assign(socket, :status, status)}
  end

  def handle_info(%Status{} = status, socket) do
    {:noreply, assign(socket, :status, status)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("connect", _value, socket) do
    Printer.Connection.Virtual.new()
    |> Printer.connect()

    {:noreply, socket}
  end
end
