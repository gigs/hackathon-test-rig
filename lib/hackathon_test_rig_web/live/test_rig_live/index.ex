defmodule HackathonTestRigWeb.TestRigLive.Index do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Test rigs
        <:actions>
          <.button variant="primary" navigate={~p"/test_rigs/new"}>
            <.icon name="hero-plus" /> New Test rig
          </.button>
        </:actions>
      </.header>

      <.table
        id="test_rigs"
        rows={@streams.test_rigs}
        row_click={fn {_id, test_rig} -> JS.navigate(~p"/test_rigs/#{test_rig}") end}
      >
        <:col :let={{_id, test_rig}} label="Name">{test_rig.name}</:col>
        <:col :let={{_id, test_rig}} label="Hostname">{test_rig.hostname}</:col>
        <:col :let={{_id, test_rig}} label="Location">{test_rig.location}</:col>
        <:action :let={{_id, test_rig}}>
          <div class="sr-only">
            <.link navigate={~p"/test_rigs/#{test_rig}"}>Show</.link>
          </div>
          <.link navigate={~p"/test_rigs/#{test_rig}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, test_rig}}>
          <.link
            phx-click={JS.push("delete", value: %{id: test_rig.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "Listing Test rigs")
     |> stream(:test_rigs, list_test_rigs())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    test_rig = Inventory.get_test_rig!(id)
    {:ok, _} = Inventory.delete_test_rig(test_rig)

    {:noreply, stream_delete(socket, :test_rigs, test_rig)}
  end

  defp list_test_rigs() do
    Inventory.list_test_rigs()
  end
end
