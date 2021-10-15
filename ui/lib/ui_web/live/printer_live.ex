defmodule UiWeb.PrinterLive do
  use Phoenix.LiveView, layout: {UiWeb.LayoutView, "live.html"}
  use Phoenix.HTML

  alias Printer.{Connection, Status}

  def render(assigns) do
    ~H"""
    <%= if @printer.status == :disconnected do %>
    <.available_connections available_connections={@available_connections}></.available_connections>
    <% end %>
    <%= if @printer.status == :connecting do %>Connecting<% end %>
    <%= if @printer.status not in [:disconnected, :connecting] do %>
    <div>Current status: <%= @printer.status %></div>
    <div>Bed Temperature: <%= @printer.bed_temperature %></div>
    <div>Extruder Temperature: <%= @printer.extruder_temperature %></div>
    <.move_axis axis={"X"}></.move_axis>
    <.move_axis axis={"Y"}></.move_axis>
    <.move_axis axis={"Z"}></.move_axis>
    <.heat_bed></.heat_bed>
    <.heat_extruder></.heat_extruder>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, printer} = Printer.status()
    available_connections = Connection.available()

    if connected?(socket) do
      Printer.subscribe()
    end

    socket =
      socket
      |> assign(:printer, printer)
      |> assign(:available_connections, available_connections)

    {:ok, socket}
  end

  def handle_info(%Status{} = status, socket) do
    {:noreply, assign(socket, :printer, status)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  require Logger

  def handle_event("connect", %{"name" => name}, socket) do
    if socket.assigns.printer.status == :disconnected do
      connection =
        Enum.find(
          socket.assigns.available_connections,
          fn c -> c.name == name end
        )

      if connection != nil do
        conn = connection.build.()

        Printer.connect(conn)
      end
    end

    {:noreply, socket}
  end

  def handle_event(
        "move",
        %{
          "amount" => amount,
          "axis" => axis
        },
        socket
      ) do
    Printer.move(%{
      axis => amount
    })

    {:noreply, socket}
  end

  def handle_event("home", %{"axis" => axis}, socket) do
    Printer.home([axis])

    {:noreply, socket}
  end

  def handle_event(
        "heat",
        params,
        socket
      ) do
    [{key, %{"temperature" => temperature}}] =
      params
      |> Map.take(["bed", "extruder"])
      |> Map.to_list()

    heat_fun =
      case key do
        "bed" -> &Printer.heat_bed/1
        "extruder" -> &Printer.heat_extruder/1
      end

    socket =
      case Integer.parse(temperature) do
        {temperature, _rest} when temperature > 0 ->
          heat_fun.(temperature)
          socket

        _ ->
          put_flash(socket, :error, "#{key} temperature must be a positive integer")
      end

    {:noreply, socket}
  end

  defp available_connections(assigns) do
    ~H"""
    <div>
      Available connections
      <%= for connection <- @available_connections do %>
        <div>
          <%= connection.name %>
          <button
            phx-click="connect"
            phx-value-name={connection.name}
          >Connect</button>
        </div>
      <% end %>
    </div>
    """
  end

  defp move_button(assigns) do
    ~H"""
    <button
      phx-click="move"
      phx-value-amount={@amount}
      phx-value-axis={@axis} >
      <%= @amount %>
      </button>
    """
  end

  defp move_axis(assigns) do
    ~H"""
    <div>
      <label><%= @axis %></label>
      <.move_button amount={-10} axis={@axis}></.move_button>
      <.move_button amount={-1} axis={@axis}></.move_button>
      <button phx-click="home" phx-value-axis={@axis}>Home</button>
      <.move_button amount={1} axis={@axis}></.move_button>
      <.move_button amount={10} axis={@axis}></.move_button>
    </div>
    """
  end

  defp heat_bed(assigns) do
    ~H"""
    <.form
      let={f}
      for={:bed}
      phx-submit="heat">
      <%= text_input f, :temperature %>
      <%= submit "Heat bed" %>
    </.form>
    """
  end

  defp heat_extruder(assigns) do
    ~H"""
    <.form
      let={f}
      for={:extruder}
      phx-submit="heat">
      <%= text_input f, :temperature %>
      <%= submit "Heat extruder" %>
    </.form>
    """
  end
end
