defmodule HackathonTestRigWeb.PhoneLive.Show do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Inventory.Phone
  alias HackathonTestRig.Workers.MaestroFlowWorker

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

      <div class="mt-10">
        <.header>
          Run a Maestro flow
          <:subtitle>Enqueue a Maestro job on this phone's queue.</:subtitle>
        </.header>
      </div>

      <.form for={@flow_form} id="maestro-flow-form" phx-submit="enqueue_flow">
        <.input
          field={@flow_form[:flow_yaml]}
          type="textarea"
          label="Flow YAML"
          rows="12"
          class="w-full textarea font-mono"
          placeholder="appId: com.example.app&#10;---&#10;- launchApp"
        />
        <.input
          field={@flow_form[:arguments_yaml]}
          type="textarea"
          label="Arguments YAML"
          rows="6"
          class="w-full textarea font-mono"
          placeholder="username: alice&#10;password: s3cret"
        />
        <footer>
          <.button phx-disable-with="Enqueuing..." variant="primary">Enqueue flow</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Phone")
     |> assign(:phone, Inventory.get_phone!(id))
     |> assign(:flow_form, blank_flow_form())}
  end

  @impl true
  def handle_event("enqueue_flow", %{"maestro" => params}, socket) do
    flow_yaml = params |> Map.get("flow_yaml", "") |> String.trim()
    arguments_yaml = Map.get(params, "arguments_yaml", "")

    with {:flow, true} <- {:flow, flow_yaml != ""},
         {:ok, arguments} <- parse_arguments_yaml(arguments_yaml) do
      phone = socket.assigns.phone

      %{"maestro_flow" => flow_yaml, "maestro_arguments" => arguments}
      |> MaestroFlowWorker.new(queue: Phone.queue_name(phone))
      |> Oban.insert!()

      {:noreply,
       socket
       |> put_flash(:info, "Maestro flow enqueued on queue #{Phone.queue_name(phone)}.")
       |> assign(:flow_form, blank_flow_form())}
    else
      {:flow, false} ->
        {:noreply,
         socket
         |> put_flash(:error, "Flow YAML can't be blank.")
         |> assign(:flow_form, to_form(params, as: :maestro))}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, "Arguments YAML is invalid: #{message}")
         |> assign(:flow_form, to_form(params, as: :maestro))}
    end
  end

  defp blank_flow_form do
    to_form(%{"flow_yaml" => "", "arguments_yaml" => ""}, as: :maestro)
  end

  defp parse_arguments_yaml(yaml) do
    yaml
    |> String.split(~r/\r?\n/)
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _} -> String.trim(line) == "" end)
    |> Enum.reduce_while({:ok, %{}}, fn {line, line_no}, {:ok, acc} ->
      case String.split(line, ":", parts: 2) do
        [key, value] when key != "" ->
          {:cont, {:ok, Map.put(acc, String.trim(key), String.trim(value))}}

        _ ->
          {:halt, {:error, "expected `key: value` on line #{line_no}"}}
      end
    end)
  end
end
