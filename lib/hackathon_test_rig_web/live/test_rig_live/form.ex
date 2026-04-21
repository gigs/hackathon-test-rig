defmodule HackathonTestRigWeb.TestRigLive.Form do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Inventory.TestRig

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage test_rig records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="test_rig-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:hostname]} type="text" label="Hostname" />
        <.input field={@form[:location]} type="text" label="Location" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Test rig</.button>
          <.button navigate={return_path(@return_to, @test_rig)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    test_rig = Inventory.get_test_rig!(id)

    socket
    |> assign(:page_title, "Edit Test rig")
    |> assign(:test_rig, test_rig)
    |> assign(:form, to_form(Inventory.change_test_rig(test_rig)))
  end

  defp apply_action(socket, :new, _params) do
    test_rig = %TestRig{}

    socket
    |> assign(:page_title, "New Test rig")
    |> assign(:test_rig, test_rig)
    |> assign(:form, to_form(Inventory.change_test_rig(test_rig)))
  end

  @impl true
  def handle_event("validate", %{"test_rig" => test_rig_params}, socket) do
    changeset = Inventory.change_test_rig(socket.assigns.test_rig, test_rig_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"test_rig" => test_rig_params}, socket) do
    save_test_rig(socket, socket.assigns.live_action, test_rig_params)
  end

  defp save_test_rig(socket, :edit, test_rig_params) do
    case Inventory.update_test_rig(socket.assigns.test_rig, test_rig_params) do
      {:ok, test_rig} ->
        {:noreply,
         socket
         |> put_flash(:info, "Test rig updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, test_rig))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_test_rig(socket, :new, test_rig_params) do
    case Inventory.create_test_rig(test_rig_params) do
      {:ok, test_rig} ->
        {:noreply,
         socket
         |> put_flash(:info, "Test rig created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, test_rig))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _test_rig), do: ~p"/test_rigs"
  defp return_path("show", test_rig), do: ~p"/test_rigs/#{test_rig}"
end
