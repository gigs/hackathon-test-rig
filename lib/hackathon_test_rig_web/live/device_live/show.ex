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

      <.form
        for={@flow_form}
        id="schedule-task-form"
        phx-submit="schedule_task"
        phx-change="form_changed"
      >
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
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Arguments</legend>
          <p class="text-xs text-base-content/60 mb-2">
            Passed to maestro as <code>-e KEY=VALUE</code>. Paste <code>KEY=VALUE</code> env vars into any field to auto-fill multiple rows.
          </p>
          <div id="arguments-list" phx-hook=".ArgumentsPaste" class="flex flex-col gap-2">
            <div
              :for={{pair, index} <- Enum.with_index(@arg_pairs)}
              id={"arg-row-#{index}"}
              data-arg-row={index}
              class="flex gap-2 items-center"
            >
              <input
                type="text"
                name={"maestro[arguments][#{index}][key]"}
                value={pair["key"]}
                placeholder="KEY"
                autocomplete="off"
                class="input input-bordered flex-1 font-mono"
                data-arg-field="key"
              />
              <span class="text-base-content/40">=</span>
              <input
                type="text"
                name={"maestro[arguments][#{index}][value]"}
                value={pair["value"]}
                placeholder="value"
                autocomplete="off"
                class="input input-bordered flex-1 font-mono"
                data-arg-field="value"
              />
              <button
                type="button"
                phx-click="remove_arg_pair"
                phx-value-index={index}
                aria-label="Remove argument"
                class="btn btn-ghost btn-sm btn-square"
              >
                <.icon name="hero-x-mark" />
              </button>
            </div>
          </div>
          <div class="mt-2">
            <button type="button" phx-click="add_arg_pair" class="btn btn-ghost btn-sm">
              <.icon name="hero-plus" /> Add argument
            </button>
          </div>
        </fieldset>
        <footer>
          <.button phx-disable-with="Scheduling..." variant="primary">Schedule task</.button>
        </footer>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ArgumentsPaste">
          export default {
            mounted() {
              this.el.addEventListener("paste", (e) => {
                const target = e.target
                if (!(target instanceof HTMLInputElement)) return
                if (target.dataset.argField !== "key" && target.dataset.argField !== "value") return

                const text = (e.clipboardData && e.clipboardData.getData("text")) || ""
                const pairs = parseEnvVars(text)

                const hasNewline = /\r?\n/.test(text)
                const isKeyField = target.dataset.argField === "key"

                if (pairs.length === 0) return
                if (!hasNewline && !isKeyField && pairs.length === 1) return

                const row = target.closest("[data-arg-row]")
                const index = row ? parseInt(row.dataset.argRow, 10) : 0

                e.preventDefault()
                this.pushEvent("bulk_paste_args", {index, pairs})
              })

              function parseEnvVars(text) {
                const lines = text.split(/\r?\n/)
                const pairs = []
                for (const raw of lines) {
                  const line = raw.trim()
                  if (!line || line.startsWith("#")) continue
                  const stripped = line.replace(/^export\s+/, "")
                  const match = stripped.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*[=:]\s*(.*)$/)
                  if (!match) continue
                  let key = match[1]
                  let value = match[2].trim()
                  // strip surrounding quotes and trailing comment
                  if (value.startsWith('"') && value.lastIndexOf('"') > 0) {
                    value = value.slice(1, value.lastIndexOf('"'))
                  } else if (value.startsWith("'") && value.lastIndexOf("'") > 0) {
                    value = value.slice(1, value.lastIndexOf("'"))
                  }
                  pairs.push({key, value})
                }
                return pairs
              }
            }
          }
        </script>
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
     |> assign(:arg_pairs, blank_arg_pairs())
     |> assign(:tasks_empty?, tasks == [])
     |> stream(:tasks, tasks)}
  end

  @impl true
  def handle_event("schedule_task", %{"maestro" => params}, socket) do
    device = socket.assigns.device
    flow_yaml = params |> Map.get("flow_yaml", "") |> String.trim()
    arg_pairs = arg_pairs_from_params(params)
    arguments = arguments_map_from_pairs(arg_pairs)
    scheduled_time = params |> Map.get("scheduled_time", "") |> String.trim()
    max_exec_time = params |> Map.get("maximum_execution_time", "") |> String.trim()

    with {:flow, true} <- {:flow, flow_yaml != ""},
         {:ok, task_attrs} <-
           build_task_attrs(device.id, flow_yaml, arguments, scheduled_time, max_exec_time),
         {:ok, _task} <- Orchestrator.create_task(task_attrs) do
      TaskScheduleWorker.ensure_scheduled()
      tasks = Orchestrator.list_tasks_for_device(device.id)

      {:noreply,
       socket
       |> put_flash(:info, "Task scheduled.")
       |> assign(:flow_form, blank_flow_form())
       |> assign(:arg_pairs, blank_arg_pairs())
       |> assign(:tasks_empty?, tasks == [])
       |> stream(:tasks, tasks, reset: true)}
    else
      {:flow, false} ->
        {:noreply,
         socket
         |> put_flash(:error, "Flow YAML can't be blank.")
         |> assign(:flow_form, to_form(params, as: :maestro))
         |> assign(:arg_pairs, arg_pairs)}

      {:error, :invalid_scheduled_time} ->
        {:noreply,
         socket
         |> put_flash(:error, "Scheduled time is required and must be a valid datetime.")
         |> assign(:flow_form, to_form(params, as: :maestro))
         |> assign(:arg_pairs, arg_pairs)}

      {:error, :invalid_max_exec_time} ->
        {:noreply,
         socket
         |> put_flash(:error, "Maximum execution time must be a positive integer.")
         |> assign(:flow_form, to_form(params, as: :maestro))
         |> assign(:arg_pairs, arg_pairs)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not create task: #{inspect(changeset.errors)}")
         |> assign(:flow_form, to_form(params, as: :maestro))
         |> assign(:arg_pairs, arg_pairs)}
    end
  end

  def handle_event("form_changed", %{"maestro" => params}, socket) do
    {:noreply,
     socket
     |> assign(:flow_form, to_form(params, as: :maestro))
     |> assign(:arg_pairs, arg_pairs_from_params(params))}
  end

  def handle_event("add_arg_pair", _params, socket) do
    pairs = socket.assigns.arg_pairs ++ [blank_pair()]
    {:noreply, assign(socket, :arg_pairs, pairs)}
  end

  def handle_event("remove_arg_pair", %{"index" => index}, socket) do
    idx = String.to_integer(index)

    pairs =
      socket.assigns.arg_pairs
      |> List.delete_at(idx)
      |> ensure_at_least_one_pair()

    {:noreply, assign(socket, :arg_pairs, pairs)}
  end

  def handle_event("bulk_paste_args", %{"index" => index, "pairs" => pairs}, socket) do
    idx = if is_integer(index), do: index, else: String.to_integer(to_string(index))

    pasted =
      pairs
      |> Enum.map(fn pair ->
        %{
          "key" => pair |> Map.get("key", "") |> to_string(),
          "value" => pair |> Map.get("value", "") |> to_string()
        }
      end)
      |> Enum.reject(fn %{"key" => k} -> String.trim(k) == "" end)

    current = socket.assigns.arg_pairs
    updated = merge_pasted_pairs(current, idx, pasted)

    {:noreply, assign(socket, :arg_pairs, updated)}
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
         steps: [
           %{
             type: :flow,
             device_id: device_id,
             maximum_execution_time: max_exec_time,
             data: %{
               "maestro_flow" => flow_yaml,
               "maestro_arguments" => arguments
             }
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
        "scheduled_time" => default_scheduled_time(),
        "maximum_execution_time" => "300"
      },
      as: :maestro
    )
  end

  defp blank_arg_pairs, do: [blank_pair()]

  defp blank_pair, do: %{"key" => "", "value" => ""}

  defp default_scheduled_time do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end

  defp arg_pairs_from_params(params) do
    case Map.get(params, "arguments") do
      nil ->
        blank_arg_pairs()

      pairs when is_map(pairs) ->
        pairs
        |> Enum.sort_by(fn {k, _} -> parse_index(k) end)
        |> Enum.map(fn {_, v} ->
          %{
            "key" => v |> Map.get("key", "") |> to_string(),
            "value" => v |> Map.get("value", "") |> to_string()
          }
        end)
        |> ensure_at_least_one_pair()

      pairs when is_list(pairs) ->
        pairs
        |> Enum.map(fn v ->
          %{
            "key" => v |> Map.get("key", "") |> to_string(),
            "value" => v |> Map.get("value", "") |> to_string()
          }
        end)
        |> ensure_at_least_one_pair()
    end
  end

  defp parse_index(k) do
    case Integer.parse(to_string(k)) do
      {i, _} -> i
      :error -> 0
    end
  end

  defp ensure_at_least_one_pair([]), do: blank_arg_pairs()
  defp ensure_at_least_one_pair(pairs), do: pairs

  defp arguments_map_from_pairs(pairs) do
    pairs
    |> Enum.map(fn %{"key" => k, "value" => v} -> {String.trim(k), String.trim(v)} end)
    |> Enum.reject(fn {k, _} -> k == "" end)
    |> Map.new()
  end

  defp merge_pasted_pairs(current, _index, []), do: current

  defp merge_pasted_pairs(current, index, [first | rest_pasted] = pasted) do
    cond do
      Enum.all?(current, &blank_pair?/1) ->
        pasted

      blank_pair?(Enum.at(current, index, blank_pair())) ->
        {head, tail} = Enum.split(current, index + 1)
        List.replace_at(head, index, first) ++ rest_pasted ++ tail

      true ->
        {head, tail} = Enum.split(current, index + 1)
        head ++ pasted ++ tail
    end
  end

  defp blank_pair?(%{"key" => k, "value" => v}),
    do: String.trim(k) == "" and String.trim(v) == ""

  defp format_scheduled(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      abs(diff) >= 86_400 -> Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
      diff >= 0 -> "#{relative_units(diff)} ago"
      true -> "in #{relative_units(-diff)}"
    end
  end

  defp relative_units(seconds) when seconds < 60, do: pluralize(seconds, "second")
  defp relative_units(seconds) when seconds < 3600, do: pluralize(div(seconds, 60), "minute")
  defp relative_units(seconds), do: pluralize(div(seconds, 3600), "hour")

  defp pluralize(1, unit), do: "1 #{unit}"
  defp pluralize(n, unit), do: "#{n} #{unit}s"

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
