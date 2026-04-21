defmodule HackathonTestRigWeb.PhoneLive.Show do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Phone {@phone.id}
        <:subtitle>This is a phone record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/phones"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/phones/#{@phone}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit phone
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@phone.name}</:item>
        <:item title="Type">{@phone.type}</:item>
        <:item title="Device model">{@phone.device_model}</:item>
        <:item title="OS version">{@phone.os_version}</:item>
        <:item title="Test rig">
          <.link :if={@phone.test_rig} navigate={~p"/test_rigs/#{@phone.test_rig}"}>
            {@phone.test_rig.name}
          </.link>
        </:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Phone")
     |> assign(:phone, Inventory.get_phone!(id))}
  end
end
