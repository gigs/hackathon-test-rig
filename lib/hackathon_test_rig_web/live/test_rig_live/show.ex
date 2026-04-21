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
          Phones
          <:subtitle>Devices attached to this test rig.</:subtitle>
          <:actions>
            <.button
              variant="primary"
              navigate={~p"/phones/new?test_rig_id=#{@test_rig.id}&return_to=test_rig"}
            >
              <.icon name="hero-plus" /> New phone
            </.button>
          </:actions>
        </.header>
      </div>

      <.table
        id="test-rig-phones"
        rows={@streams.phones}
        row_click={fn {_id, phone} -> JS.navigate(~p"/phones/#{phone}") end}
      >
        <:col :let={{_id, phone}} label="Name">{phone.name}</:col>
        <:col :let={{_id, phone}} label="Type">{phone.type}</:col>
        <:col :let={{_id, phone}} label="Device model">{phone.device_model}</:col>
        <:col :let={{_id, phone}} label="OS version">{phone.os_version}</:col>
        <:action :let={{_id, phone}}>
          <div class="sr-only">
            <.link navigate={~p"/phones/#{phone}"}>Show</.link>
          </div>
          <.link navigate={~p"/phones/#{phone}/edit?return_to=test_rig"}>Edit</.link>
        </:action>
        <:action :let={{id, phone}}>
          <.link
            phx-click={JS.push("delete_phone", value: %{id: phone.id}) |> hide("##{id}")}
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
     |> stream(:phones, Inventory.list_phones_for_test_rig(test_rig.id))}
  end

  @impl true
  def handle_event("delete_phone", %{"id" => id}, socket) do
    phone = Inventory.get_phone!(id)
    {:ok, _} = Inventory.delete_phone(phone)

    {:noreply, stream_delete(socket, :phones, phone)}
  end
end
