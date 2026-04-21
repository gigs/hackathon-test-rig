defmodule HackathonTestRigWeb.PhoneLive.Form do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Inventory.Phone

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage phone records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="phone-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          prompt="Choose a value"
          options={Ecto.Enum.values(HackathonTestRig.Inventory.Phone, :type)}
        />
        <.input field={@form[:device_model]} type="text" label="Device model" />
        <.input field={@form[:os_version]} type="text" label="OS version" />
        <.input
          field={@form[:test_rig_id]}
          type="select"
          label="Test rig"
          prompt="Choose a test rig"
          options={@test_rig_options}
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Phone</.button>
          <.button navigate={return_path(@return_to, @phone)}>Cancel</.button>
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
    phone = Inventory.get_phone!(id)

    socket
    |> assign(:page_title, "Edit Phone")
    |> assign(:phone, phone)
    |> assign(:form, to_form(Inventory.change_phone(phone)))
  end

  defp apply_action(socket, :new, params) do
    phone = %Phone{test_rig_id: parse_test_rig_id(params["test_rig_id"])}

    socket
    |> assign(:page_title, "New Phone")
    |> assign(:phone, phone)
    |> assign(:form, to_form(Inventory.change_phone(phone)))
  end

  defp parse_test_rig_id(nil), do: nil

  defp parse_test_rig_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  @impl true
  def handle_event("validate", %{"phone" => phone_params}, socket) do
    changeset = Inventory.change_phone(socket.assigns.phone, phone_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"phone" => phone_params}, socket) do
    save_phone(socket, socket.assigns.live_action, phone_params)
  end

  defp save_phone(socket, :edit, phone_params) do
    case Inventory.update_phone(socket.assigns.phone, phone_params) do
      {:ok, phone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Phone updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, phone))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_phone(socket, :new, phone_params) do
    case Inventory.create_phone(phone_params) do
      {:ok, phone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Phone created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, phone))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _phone), do: ~p"/phones"
  defp return_path("show", phone), do: ~p"/phones/#{phone}"

  defp return_path("test_rig", %Phone{test_rig_id: id}) when not is_nil(id),
    do: ~p"/test_rigs/#{id}"

  defp return_path("test_rig", _phone), do: ~p"/test_rigs"
end
