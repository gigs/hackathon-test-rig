defmodule HackathonTestRigWeb.TestRigLive.Show do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Test rig {@test_rig.name}
        <:subtitle>This is a test_rig record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/test_rigs"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/test_rigs/#{@test_rig}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit test_rig
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@test_rig.name}</:item>
        <:item title="Hostname">{@test_rig.hostname}</:item>
        <:item title="Location">{@test_rig.location}</:item>
      </.list>

      <div class="mt-10">
        <.header>
          Devices
          <:subtitle>Devices attached to this test rig.</:subtitle>
          <:actions>
            <.button
              variant="primary"
              navigate={~p"/devices/new?test_rig_id=#{@test_rig.id}&return_to=test_rig"}
            >
              <.icon name="hero-plus" /> New device
            </.button>
          </:actions>
        </.header>
      </div>

      <.table
        id="test-rig-devices"
        rows={@streams.devices}
        row_click={fn {_id, device} -> JS.navigate(~p"/devices/#{device}") end}
      >
        <:col :let={{_id, device}} label="Brand">{device.brand}</:col>
        <:col :let={{_id, device}} label="Name">{device.name}</:col>
        <:col :let={{_id, device}} label="Type">{device.type}</:col>
        <:action :let={{_id, device}}>
          <div class="sr-only">
            <.link navigate={~p"/devices/#{device}"}>Show</.link>
          </div>
          <.link navigate={~p"/devices/#{device}/edit?return_to=test_rig"}>Edit</.link>
        </:action>
        <:action :let={{id, device}}>
          <.link
            phx-click={JS.push("delete_device", value: %{id: device.id}) |> hide("##{id}")}
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
  def mount(%{"id" => id}, _session, socket) do
    test_rig = Inventory.get_test_rig!(id)

    {:ok,
     socket
     |> assign(:page_title, "Show Test rig")
     |> assign(:test_rig, test_rig)
     |> stream(:devices, Inventory.list_devices_for_test_rig(test_rig.id))}
  end

  @impl true
  def handle_event("delete_device", %{"id" => id}, socket) do
    device = Inventory.get_device!(id)
    {:ok, _} = Inventory.delete_device(device)

    {:noreply, stream_delete(socket, :devices, device)}
  end
end
