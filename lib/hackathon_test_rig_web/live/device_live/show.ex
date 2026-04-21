defmodule HackathonTestRigWeb.DeviceLive.Show do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.FlowTemplates
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
          <:subtitle>Queue a sequence of Maestro flows to run on this device now or later.</:subtitle>
        </.header>
      </div>

      <.form
        for={@task_form}
        id="schedule-task-form"
        phx-submit="schedule_task"
        phx-change="form_changed"
      >
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@task_form[:scheduled_time]}
            type="datetime-local"
            label="Scheduled time (UTC)"
          />
          <.input
            field={@task_form[:maximum_execution_time]}
            type="number"
            label="Maximum execution time (seconds)"
            min="1"
          />
        </div>

        <div class="mt-6 flex items-center justify-between">
          <h2 class="text-lg font-semibold">Steps</h2>
          <button type="button" phx-click="add_step" class="btn btn-sm">
            <.icon name="hero-plus" /> Add step
          </button>
        </div>

        <div id="step-forms" class="mt-2 flex flex-col gap-4">
          <div
            :for={{step, position} <- Enum.with_index(@step_forms)}
            id={"step-form-#{step.id}"}
            data-step-id={step.id}
            class="card bg-base-100 border border-base-200"
          >
            <div class="card-body gap-4">
              <div class="flex items-center justify-between">
                <h3 class="card-title text-base">Step {position + 1}</h3>
                <button
                  :if={length(@step_forms) > 1}
                  type="button"
                  phx-click="remove_step"
                  phx-value-id={step.id}
                  aria-label="Remove step"
                  class="btn btn-ghost btn-sm btn-square"
                >
                  <.icon name="hero-trash" />
                </button>
              </div>

              <label class="fieldset">
                <span class="fieldset-legend">Flow template</span>
                <div class="w-full select">
                  <select name={"maestro[steps][#{step.id}][flow_template]"}>
                    <option
                      :for={{label, value} <- flow_template_options(@flow_templates)}
                      value={value}
                      selected={value == step.template}
                    >
                      {label}
                    </option>
                  </select>
                </div>
              </label>

              <label :if={step.template == @custom_template} class="fieldset">
                <span class="fieldset-legend">Flow YAML</span>
                <textarea
                  name={"maestro[steps][#{step.id}][flow_yaml]"}
                  rows="12"
                  class="w-full textarea textarea-bordered font-mono"
                  placeholder="appId: com.example.app&#10;---&#10;- launchApp"
                >{step.yaml}</textarea>
              </label>

              <fieldset class="fieldset">
                <legend class="fieldset-legend">Arguments</legend>
                <p class="text-xs text-base-content/60 mb-2">
                  Passed to maestro as <code>-e KEY=VALUE</code>. Paste <code>KEY=VALUE</code>
                  env vars into any field to auto-fill multiple rows.
                </p>
                <div
                  id={"arguments-list-#{step.id}"}
                  phx-hook=".ArgumentsPaste"
                  data-step-id={step.id}
                  class="flex flex-col gap-2"
                >
                  <div
                    :for={{pair, index} <- Enum.with_index(step.arg_pairs)}
                    id={"arg-row-#{step.id}-#{index}"}
                    data-arg-row={index}
                    class="flex gap-2 items-center"
                  >
                    <input
                      type="text"
                      name={"maestro[steps][#{step.id}][arguments][#{index}][key]"}
                      value={pair["key"]}
                      placeholder="KEY"
                      autocomplete="off"
                      class="input input-bordered flex-1 font-mono"
                      data-arg-field="key"
                    />
                    <span class="text-base-content/40">=</span>
                    <input
                      type="text"
                      name={"maestro[steps][#{step.id}][arguments][#{index}][value]"}
                      value={pair["value"]}
                      placeholder="value"
                      autocomplete="off"
                      class="input input-bordered flex-1 font-mono"
                      data-arg-field="value"
                    />
                    <button
                      type="button"
                      phx-click="remove_arg_pair"
                      phx-value-step={step.id}
                      phx-value-index={index}
                      aria-label="Remove argument"
                      class="btn btn-ghost btn-sm btn-square"
                    >
                      <.icon name="hero-x-mark" />
                    </button>
                  </div>
                </div>
                <div class="mt-2">
                  <button
                    type="button"
                    phx-click="add_arg_pair"
                    phx-value-step={step.id}
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-plus" /> Add argument
                  </button>
                </div>
              </fieldset>
            </div>
          </div>
        </div>

        <footer class="mt-6">
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
                const stepId = this.el.dataset.stepId

                e.preventDefault()
                this.pushEvent("bulk_paste_args", {step: stepId, index, pairs})
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
              <div class="text-sm font-medium">
                Task #{task.id} · {pluralize(length(task.steps), "step")}
              </div>
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
    flow_templates = FlowTemplates.list()
    default_template = default_template(flow_templates)

    {:ok,
     socket
     |> assign(:page_title, "Show Device")
     |> assign(:device, device)
     |> assign(:flow_templates, flow_templates)
     |> assign(:custom_template, FlowTemplates.custom_name())
     |> assign(:task_form, blank_task_form())
     |> assign(:step_forms, [new_step_form("0", default_template)])
     |> assign(:step_counter, 1)
     |> assign(:tasks_empty?, tasks == [])
     |> stream(:tasks, tasks)}
  end

  @impl true
  def handle_event("schedule_task", %{"maestro" => params}, socket) do
    device = socket.assigns.device
    custom = socket.assigns.custom_template
    available = socket.assigns.flow_templates
    scheduled_time = params |> Map.get("scheduled_time", "") |> String.trim()
    max_exec_time = params |> Map.get("maximum_execution_time", "") |> String.trim()

    step_forms = sync_step_forms(socket.assigns.step_forms, params, available, custom)

    with {:ok, step_datas} <- build_step_datas(step_forms, custom),
         {:ok, task_attrs} <-
           build_task_attrs(device.id, step_datas, scheduled_time, max_exec_time),
         {:ok, _task} <- Orchestrator.create_task(task_attrs) do
      TaskScheduleWorker.ensure_scheduled()
      tasks = Orchestrator.list_tasks_for_device(device.id)
      default_template = default_template(available)

      {:noreply,
       socket
       |> put_flash(:info, "Task scheduled.")
       |> assign(:task_form, blank_task_form())
       |> assign(:step_forms, [new_step_form("0", default_template)])
       |> assign(:step_counter, 1)
       |> assign(:tasks_empty?, tasks == [])
       |> stream(:tasks, tasks, reset: true)}
    else
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, flow_error_message(reason))
         |> assign(:task_form, to_form(params, as: :maestro))
         |> assign(:step_forms, step_forms)}
    end
  end

  def handle_event("form_changed", %{"maestro" => params}, socket) do
    step_forms =
      sync_step_forms(
        socket.assigns.step_forms,
        params,
        socket.assigns.flow_templates,
        socket.assigns.custom_template
      )

    {:noreply,
     socket
     |> assign(:task_form, to_form(params, as: :maestro))
     |> assign(:step_forms, step_forms)}
  end

  def handle_event("add_step", _params, socket) do
    id = Integer.to_string(socket.assigns.step_counter)
    template = default_template(socket.assigns.flow_templates)

    {:noreply,
     socket
     |> assign(:step_forms, socket.assigns.step_forms ++ [new_step_form(id, template)])
     |> assign(:step_counter, socket.assigns.step_counter + 1)}
  end

  def handle_event("remove_step", %{"id" => id}, socket) do
    step_forms = Enum.reject(socket.assigns.step_forms, &(&1.id == id))
    step_forms = if step_forms == [], do: socket.assigns.step_forms, else: step_forms
    {:noreply, assign(socket, :step_forms, step_forms)}
  end

  def handle_event("add_arg_pair", %{"step" => step_id}, socket) do
    step_forms =
      update_step(socket.assigns.step_forms, step_id, fn step ->
        %{step | arg_pairs: step.arg_pairs ++ [blank_pair()]}
      end)

    {:noreply, assign(socket, :step_forms, step_forms)}
  end

  def handle_event("remove_arg_pair", %{"step" => step_id, "index" => index}, socket) do
    idx = String.to_integer(index)

    step_forms =
      update_step(socket.assigns.step_forms, step_id, fn step ->
        pairs =
          step.arg_pairs
          |> List.delete_at(idx)
          |> ensure_at_least_one_pair()

        %{step | arg_pairs: pairs}
      end)

    {:noreply, assign(socket, :step_forms, step_forms)}
  end

  def handle_event("bulk_paste_args", %{"step" => step_id, "index" => index, "pairs" => pairs}, socket) do
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

    step_forms =
      update_step(socket.assigns.step_forms, step_id, fn step ->
        %{step | arg_pairs: merge_pasted_pairs(step.arg_pairs, idx, pasted)}
      end)

    {:noreply, assign(socket, :step_forms, step_forms)}
  end

  @impl true
  def handle_info(:tasks_changed, socket) do
    tasks = Orchestrator.list_tasks_for_device(socket.assigns.device.id)

    {:noreply,
     socket
     |> assign(:tasks_empty?, tasks == [])
     |> stream(:tasks, tasks, reset: true)}
  end

  defp new_step_form(id, template) do
    yaml = template_yaml(template)
    pairs = initial_arg_pairs(yaml)

    %{
      id: id,
      template: template,
      yaml: "",
      arg_pairs: pairs,
      arg_values: values_from_pairs(pairs)
    }
  end

  defp update_step(step_forms, id, fun) do
    Enum.map(step_forms, fn
      %{id: ^id} = step -> fun.(step)
      step -> step
    end)
  end

  defp sync_step_forms(step_forms, params, available, custom) do
    steps_params = Map.get(params, "steps", %{})

    Enum.map(step_forms, fn step ->
      incoming = Map.get(steps_params, step.id, %{})
      sync_step(step, incoming, available, custom)
    end)
  end

  defp sync_step(step, incoming, available, custom) do
    template = selected_template(incoming, available, step.template)
    template_changed? = template != step.template

    yaml =
      if template == custom do
        Map.get(incoming, "flow_yaml", step.yaml)
      else
        step.yaml
      end

    current_pairs = arg_pairs_from_params(incoming)
    merged_values = Map.merge(step.arg_values, values_from_pairs(current_pairs))

    pairs =
      cond do
        template_changed? and template != custom ->
          template_arg_pairs(template, merged_values)

        template_changed? ->
          current_pairs

        true ->
          source_yaml = effective_flow_yaml(template, yaml, custom)
          add_missing_arg_pairs(current_pairs, extract_yaml_arguments(source_yaml))
      end

    %{step | template: template, yaml: yaml, arg_pairs: pairs, arg_values: merged_values}
  end

  defp build_step_datas(step_forms, custom) do
    Enum.reduce_while(step_forms, {:ok, []}, fn step, {:ok, acc} ->
      case resolve_flow_yaml(step.template, step.yaml, custom) do
        {:ok, yaml} ->
          arguments = arguments_map_from_pairs(step.arg_pairs)
          {:cont, {:ok, acc ++ [{yaml, arguments}]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp build_task_attrs(device_id, step_datas, scheduled_time_str, max_exec_time_str) do
    with {:ok, scheduled_time} <- parse_scheduled_time(scheduled_time_str),
         {:ok, max_exec_time} <- parse_max_exec_time(max_exec_time_str) do
      steps =
        Enum.map(step_datas, fn {flow_yaml, arguments} ->
          %{
            type: :flow,
            device_id: device_id,
            maximum_execution_time: max_exec_time,
            data: %{
              "maestro_flow" => flow_yaml,
              "maestro_arguments" => arguments
            }
          }
        end)

      {:ok,
       %{
         scheduled_time: scheduled_time,
         maximum_execution_time: max_exec_time,
         steps: steps
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

  defp blank_task_form do
    to_form(
      %{
        "scheduled_time" => default_scheduled_time(),
        "maximum_execution_time" => "300"
      },
      as: :maestro
    )
  end

  defp flow_template_options(templates) do
    custom = FlowTemplates.custom_name()

    Enum.map(templates, fn name ->
      label = if name == custom, do: "Custom", else: name
      {label, name}
    end)
  end

  defp default_template([first | _]), do: first
  defp default_template(_), do: FlowTemplates.custom_name()

  defp selected_template(params, available, fallback) do
    name = Map.get(params, "flow_template", fallback)
    if name in available, do: name, else: fallback
  end

  defp template_yaml(name) do
    case FlowTemplates.load(name) do
      {:ok, yaml} -> yaml
      :error -> ""
    end
  end

  defp effective_flow_yaml(template, user_yaml, custom) do
    if template == custom do
      user_yaml
    else
      template_yaml(template)
    end
  end

  defp resolve_flow_yaml(template, user_yaml, custom) do
    yaml = effective_flow_yaml(template, user_yaml, custom) |> String.trim()

    cond do
      yaml == "" and template == custom -> {:error, :blank_flow}
      yaml == "" -> {:error, :unknown_template}
      true -> {:ok, yaml}
    end
  end

  defp initial_arg_pairs(yaml) do
    case extract_yaml_arguments(yaml) do
      [] -> blank_arg_pairs()
      names -> Enum.map(names, fn name -> %{"key" => name, "value" => ""} end)
    end
  end

  defp template_arg_pairs(template, arg_values) do
    template
    |> template_yaml()
    |> extract_yaml_arguments()
    |> Enum.map(fn name -> %{"key" => name, "value" => Map.get(arg_values, name, "")} end)
    |> ensure_at_least_one_pair()
  end

  defp values_from_pairs(pairs) do
    pairs
    |> Enum.map(fn %{"key" => k, "value" => v} -> {String.trim(k), v} end)
    |> Enum.reject(fn {k, _} -> k == "" end)
    |> Map.new()
  end

  defp flow_error_message(:blank_flow), do: "Flow YAML can't be blank."
  defp flow_error_message(:unknown_template), do: "Selected flow template could not be loaded."

  defp flow_error_message(:invalid_scheduled_time),
    do: "Scheduled time is required and must be a valid datetime."

  defp flow_error_message(:invalid_max_exec_time),
    do: "Maximum execution time must be a positive integer."

  defp flow_error_message(%Ecto.Changeset{} = changeset),
    do: "Could not create task: #{inspect(changeset.errors)}"

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

  defp extract_yaml_arguments(yaml) when is_binary(yaml) do
    yaml
    |> do_extract_args([])
    |> Enum.reverse()
    |> Enum.uniq()
  end

  defp extract_yaml_arguments(_), do: []

  defp do_extract_args(<<>>, acc), do: acc
  defp do_extract_args(<<"\\\\", rest::binary>>, acc), do: do_extract_args(rest, acc)
  defp do_extract_args(<<"\\$", rest::binary>>, acc), do: do_extract_args(rest, acc)

  defp do_extract_args(<<"${", rest::binary>>, acc) do
    case parse_arg_name(rest, <<>>) do
      {:ok, name, remaining} -> do_extract_args(remaining, [name | acc])
      :error -> do_extract_args(rest, acc)
    end
  end

  defp do_extract_args(<<_, rest::binary>>, acc), do: do_extract_args(rest, acc)

  defp parse_arg_name(<<c, rest::binary>>, <<>>)
       when (c >= ?A and c <= ?Z) or (c >= ?a and c <= ?z) or c == ?_ do
    parse_arg_name(rest, <<c>>)
  end

  defp parse_arg_name(<<c, rest::binary>>, acc)
       when (c >= ?A and c <= ?Z) or (c >= ?a and c <= ?z) or (c >= ?0 and c <= ?9) or c == ?_ do
    parse_arg_name(rest, <<acc::binary, c>>)
  end

  defp parse_arg_name(<<?}, rest::binary>>, acc) when byte_size(acc) > 0 do
    {:ok, acc, rest}
  end

  defp parse_arg_name(_, _), do: :error

  defp add_missing_arg_pairs(pairs, []), do: pairs

  defp add_missing_arg_pairs(pairs, names) do
    existing_keys =
      pairs
      |> Enum.map(fn %{"key" => k} -> String.trim(k) end)
      |> MapSet.new()

    missing =
      names
      |> Enum.reject(&MapSet.member?(existing_keys, &1))
      |> Enum.map(fn name -> %{"key" => name, "value" => ""} end)

    cond do
      missing == [] -> pairs
      Enum.all?(pairs, &blank_pair?/1) -> missing
      true -> pairs ++ missing
    end
  end

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
