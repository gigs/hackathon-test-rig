defmodule HackathonTestRigWeb.PhoneLive.Index do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Phones
        <:actions>
          <.button variant="primary" navigate={~p"/phones/new"}>
            <.icon name="hero-plus" /> New Phone
          </.button>
        </:actions>
      </.header>

      <.table
        id="phones"
        rows={@streams.phones}
        row_click={fn {_id, phone} -> JS.navigate(~p"/phones/#{phone}") end}
      >
        <:col :let={{_id, phone}} label="Name">{phone.name}</:col>
        <:col :let={{_id, phone}} label="Type">{phone.type}</:col>
        <:col :let={{_id, phone}} label="Device model">{phone.device_model}</:col>
        <:col :let={{_id, phone}} label="OS version">{phone.os_version}</:col>
        <:col :let={{_id, phone}} label="Test rig">{phone.test_rig && phone.test_rig.name}</:col>
        <:action :let={{_id, phone}}>
          <div class="sr-only">
            <.link navigate={~p"/phones/#{phone}"}>Show</.link>
          </div>
          <.link navigate={~p"/phones/#{phone}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, phone}}>
          <.link
            phx-click={JS.push("delete", value: %{id: phone.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "Listing Phones")
     |> stream(:phones, list_phones())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    phone = Inventory.get_phone!(id)
    {:ok, _} = Inventory.delete_phone(phone)

    {:noreply, stream_delete(socket, :phones, phone)}
  end

  defp list_phones() do
    Inventory.list_phones()
  end
end
