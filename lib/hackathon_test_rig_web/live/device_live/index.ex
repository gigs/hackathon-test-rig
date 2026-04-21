defmodule HackathonTestRigWeb.DeviceLive.Index do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Devices
        <:actions>
          <.button variant="primary" navigate={~p"/devices/new"}>
            <.icon name="hero-plus" /> New Device
          </.button>
        </:actions>
      </.header>

      <.table
        id="devices"
        rows={@streams.devices}
        row_click={fn {_id, device} -> JS.navigate(~p"/devices/#{device}") end}
      >
        <:col :let={{_id, device}} label="Brand">{device.brand}</:col>
        <:col :let={{_id, device}} label="Name">{device.name}</:col>
        <:col :let={{_id, device}} label="Type">{device.type}</:col>
        <:col :let={{_id, device}} label="Test rig">{device.test_rig && device.test_rig.name}</:col>
        <:action :let={{_id, device}}>
          <div class="sr-only">
            <.link navigate={~p"/devices/#{device}"}>Show</.link>
          </div>
          <.link navigate={~p"/devices/#{device}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, device}}>
          <.link
            phx-click={JS.push("delete", value: %{id: device.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Devices")
     |> stream(:devices, list_devices())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    device = Inventory.get_device!(id)
    {:ok, _} = Inventory.delete_device(device)

    {:noreply, stream_delete(socket, :devices, device)}
  end

  defp list_devices() do
    Inventory.list_devices()
  end
end
