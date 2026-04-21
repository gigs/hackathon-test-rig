defmodule HackathonTestRigWeb.TestRigLive.Show do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Test rig {@test_rig.id}
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
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Test rig")
     |> assign(:test_rig, Inventory.get_test_rig!(id))}
  end
end
