defmodule HackathonTestRigWeb.DeviceLive.Form do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Inventory.Device

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage device records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="device-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:brand]} type="text" label="Brand" />
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          prompt="Choose a value"
          options={Ecto.Enum.values(HackathonTestRig.Inventory.Device, :type)}
        />
        <.input
          field={@form[:test_rig_id]}
          type="select"
          label="Test rig"
          prompt="Choose a test rig"
          options={@test_rig_options}
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Device</.button>
          <.button navigate={return_path(@return_to, @device)}>Cancel</.button>
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
     |> assign(:test_rig_options, test_rig_options())
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp test_rig_options do
    Enum.map(Inventory.list_test_rigs(), &{&1.name, &1.id})
  end

  defp return_to("show"), do: "show"
  defp return_to("test_rig"), do: "test_rig"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    device = Inventory.get_device!(id)

    socket
    |> assign(:page_title, "Edit Device")
    |> assign(:device, device)
    |> assign(:form, to_form(Inventory.change_device(device)))
  end

  defp apply_action(socket, :new, params) do
    device = %Device{test_rig_id: parse_test_rig_id(params["test_rig_id"])}

    socket
    |> assign(:page_title, "New Device")
    |> assign(:device, device)
    |> assign(:form, to_form(Inventory.change_device(device)))
  end

  defp parse_test_rig_id(nil), do: nil

  defp parse_test_rig_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  @impl true
  def handle_event("validate", %{"device" => device_params}, socket) do
    changeset = Inventory.change_device(socket.assigns.device, device_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"device" => device_params}, socket) do
    save_device(socket, socket.assigns.live_action, device_params)
  end

  defp save_device(socket, :edit, device_params) do
    case Inventory.update_device(socket.assigns.device, device_params) do
      {:ok, device} ->
        {:noreply,
         socket
         |> put_flash(:info, "Device updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, device))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_device(socket, :new, device_params) do
    case Inventory.create_device(device_params) do
      {:ok, device} ->
        {:noreply,
         socket
         |> put_flash(:info, "Device created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, device))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _device), do: ~p"/devices"
  defp return_path("show", device), do: ~p"/devices/#{device}"

  defp return_path("test_rig", %Device{test_rig_id: id}) when not is_nil(id),
    do: ~p"/test_rigs/#{id}"

  defp return_path("test_rig", _device), do: ~p"/test_rigs"
end
