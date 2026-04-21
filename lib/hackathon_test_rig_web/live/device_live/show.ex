defmodule HackathonTestRigWeb.DeviceLive.Show do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Orchestrator
  alias HackathonTestRig.Workers.TaskScheduleWorker

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Device {@device.id}
        <:subtitle>This is a device record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/devices"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/devices/#{@device}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit device
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Brand">{@device.brand}</:item>
        <:item title="Name">{@device.name}</:item>
        <:item title="Type">{@device.type}</:item>
        <:item title="Test rig">
          <.link :if={@device.test_rig} navigate={~p"/test_rigs/#{@device.test_rig}"}>
            {@device.test_rig.name}
          </.link>
        </:item>
      </.list>

      <div class="mt-10">
        <.header>
          Schedule a task
          <:subtitle>Queue a Maestro flow to run on this device now or later.</:subtitle>
        </.header>
      </div>

      <.form for={@flow_form} id="schedule-task-form" phx-submit="schedule_task">
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@flow_form[:scheduled_time]}
            type="datetime-local"
            label="Scheduled time (UTC)"
          />
          <.input
            field={@flow_form[:maximum_execution_time]}
            type="number"
            label="Maximum execution time (seconds)"
            min="1"
          />
        </div>
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
          <.button phx-disable-with="Scheduling..." variant="primary">Schedule task</.button>
        </footer>
      </.form>

      <div class="mt-10">
        <.header>
          Task history
          <:subtitle>Tasks scheduled on this device, newest first.</:subtitle>
        </.header>
      </div>

      <div
        :if={@tasks_empty?}
        id="device-tasks-empty"
        class="py-8 text-center text-base-content/60"
      >
        No tasks scheduled yet.
      </div>
      <div id="device-tasks" phx-update="stream">
        <div
          :for={{dom_id, task} <- @streams.tasks}
          id={dom_id}
          class="flex items-center justify-between gap-4 border-b border-base-200 py-3"
        >
          <div class="flex items-center gap-3">
            <span class={["badge", task_status_class(task.status)]}>
              {task.status}
            </span>
            <div>
              <div class="text-sm font-medium">Task #{task.id}</div>
              <div class="text-xs text-base-content/60">
                {format_scheduled(task.scheduled_time)} · max {task.maximum_execution_time}s
              </div>
            </div>
          </div>
          <div class="text-xs text-base-content/60">
            {scheduled_label(task.scheduled_time)}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Orchestrator.subscribe_tasks()

    device = Inventory.get_device!(id)
    tasks = Orchestrator.list_tasks_for_device(device.id)

    {:ok,
     socket
     |> assign(:page_title, "Show Device")
     |> assign(:device, device)
     |> assign(:flow_form, blank_flow_form())
     |> assign(:tasks_empty?, tasks == [])
     |> stream(:tasks, tasks)}
  end

  @impl true
  def handle_event("schedule_task", %{"maestro" => params}, socket) do
    device = socket.assigns.device
    flow_yaml = params |> Map.get("flow_yaml", "") |> String.trim()
    arguments_yaml = Map.get(params, "arguments_yaml", "")
    scheduled_time = params |> Map.get("scheduled_time", "") |> String.trim()
    max_exec_time = params |> Map.get("maximum_execution_time", "") |> String.trim()

    with {:flow, true} <- {:flow, flow_yaml != ""},
         {:ok, arguments} <- parse_arguments_yaml(arguments_yaml),
         {:ok, task_attrs} <-
           build_task_attrs(device.id, flow_yaml, arguments, scheduled_time, max_exec_time),
         {:ok, _task} <- Orchestrator.create_task(task_attrs) do
      TaskScheduleWorker.ensure_scheduled()
      tasks = Orchestrator.list_tasks_for_device(device.id)

      {:noreply,
       socket
       |> put_flash(:info, "Task scheduled.")
       |> assign(:flow_form, blank_flow_form())
       |> assign(:tasks_empty?, tasks == [])
       |> stream(:tasks, tasks, reset: true)}
    else
      {:flow, false} ->
        {:noreply,
         socket
         |> put_flash(:error, "Flow YAML can't be blank.")
         |> assign(:flow_form, to_form(params, as: :maestro))}

      {:error, :invalid_scheduled_time} ->
        {:noreply,
         socket
         |> put_flash(:error, "Scheduled time is required and must be a valid datetime.")
         |> assign(:flow_form, to_form(params, as: :maestro))}

      {:error, :invalid_max_exec_time} ->
        {:noreply,
         socket
         |> put_flash(:error, "Maximum execution time must be a positive integer.")
         |> assign(:flow_form, to_form(params, as: :maestro))}

      {:error, message} when is_binary(message) ->
        {:noreply,
         socket
         |> put_flash(:error, "Arguments YAML is invalid: #{message}")
         |> assign(:flow_form, to_form(params, as: :maestro))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not create task: #{inspect(changeset.errors)}")
         |> assign(:flow_form, to_form(params, as: :maestro))}
    end
  end

  @impl true
  def handle_info(:tasks_changed, socket) do
    tasks = Orchestrator.list_tasks_for_device(socket.assigns.device.id)

    {:noreply,
     socket
     |> assign(:tasks_empty?, tasks == [])
     |> stream(:tasks, tasks, reset: true)}
  end

  defp build_task_attrs(device_id, flow_yaml, arguments, scheduled_time_str, max_exec_time_str) do
    with {:ok, scheduled_time} <- parse_scheduled_time(scheduled_time_str),
         {:ok, max_exec_time} <- parse_max_exec_time(max_exec_time_str) do
      {:ok,
       %{
         scheduled_time: scheduled_time,
         maximum_execution_time: max_exec_time,
         flows: [
           %{
             device_id: device_id,
             maestro_flow: flow_yaml,
             maestro_arguments: arguments,
             maximum_execution_time: max_exec_time
           }
         ]
       }}
    end
  end

  defp parse_scheduled_time(""), do: {:error, :invalid_scheduled_time}

  defp parse_scheduled_time(str) do
    # datetime-local inputs look like "2026-04-21T15:30" or "2026-04-21T15:30:00"
    with {:ok, naive} <- NaiveDateTime.from_iso8601(ensure_seconds(str)) do
      {:ok, DateTime.from_naive!(naive, "Etc/UTC") |> DateTime.truncate(:second)}
    else
      _ -> {:error, :invalid_scheduled_time}
    end
  end

  defp ensure_seconds(str) do
    case String.split(str, ":") do
      [_, _] -> str <> ":00"
      _ -> str
    end
  end

  defp parse_max_exec_time(str) do
    case Integer.parse(str) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> {:error, :invalid_max_exec_time}
    end
  end

  defp blank_flow_form do
    to_form(
      %{
        "flow_yaml" => "",
        "arguments_yaml" => "",
        "scheduled_time" => default_scheduled_time(),
        "maximum_execution_time" => "300"
      },
      as: :maestro
    )
  end

  defp default_scheduled_time do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%dT%H:%M")
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

  defp format_scheduled(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp scheduled_label(%DateTime{} = dt) do
    case DateTime.compare(dt, DateTime.utc_now()) do
      :gt -> "scheduled"
      _ -> "past-due"
    end
  end

  defp task_status_class(:pending), do: "badge-ghost"
  defp task_status_class(:executing), do: "badge-info"
  defp task_status_class(:completed), do: "badge-success"
  defp task_status_class(:failed), do: "badge-error"
end
