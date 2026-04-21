defmodule HackathonTestRig.Orchestrator do
  @moduledoc """
  The Orchestrator context.

  Owns tasks: scheduled bundles of steps (Maestro flows, reservations, ...) to
  run across devices.
  """

  import Ecto.Query, warn: false
  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Inventory.Device
  alias HackathonTestRig.Orchestrator.Task
  alias HackathonTestRig.Orchestrator.TaskStep
  alias HackathonTestRig.Repo
  alias HackathonTestRig.Workers.MaestroFlowWorker

  @active_job_states ~w(scheduled available executing retryable)
  @tasks_topic "orchestrator:tasks"

  @doc """
  Subscribe the current process to task change notifications.
  The process will receive `:tasks_changed` messages on task insert/update/delete.
  """
  def subscribe_tasks do
    Phoenix.PubSub.subscribe(HackathonTestRig.PubSub, @tasks_topic)
  end

  defp broadcast_tasks_changed do
    Phoenix.PubSub.broadcast(HackathonTestRig.PubSub, @tasks_topic, :tasks_changed)
  end

  @doc """
  Returns the list of tasks.
  """
  def list_tasks do
    Repo.all(from t in Task, order_by: [asc: t.scheduled_time], preload: :steps)
  end

  @doc """
  Returns tasks with the given status.
  """
  def list_tasks_by_status(status) when status in [:pending, :executing, :completed, :failed] do
    Repo.all(
      from t in Task,
        where: t.status == ^status,
        order_by: [asc: t.scheduled_time],
        preload: :steps
    )
  end

  @doc """
  Returns tasks that include a step referencing the given device id.

  Ordered with most recently scheduled first.
  """
  def list_tasks_for_device(device_id) do
    Repo.all(
      from t in Task,
        join: s in assoc(t, :steps),
        where: s.device_id == ^device_id,
        distinct: true,
        order_by: [desc: t.scheduled_time],
        preload: :steps
    )
  end

  @doc """
  Returns pending tasks whose scheduled time has arrived, ordered by scheduled_time.
  """
  def list_runnable_tasks(now \\ DateTime.utc_now()) do
    Repo.all(
      from t in Task,
        where: t.status == :pending and t.scheduled_time <= ^now,
        order_by: [asc: t.scheduled_time],
        preload: :steps
    )
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.
  """
  def get_task!(id), do: Task |> Repo.get!(id) |> Repo.preload(:steps)

  @doc """
  Creates a task.
  """
  def create_task(attrs) do
    result =
      %Task{}
      |> Task.changeset(attrs)
      |> Repo.insert()

    with {:ok, _task} <- result, do: broadcast_tasks_changed()
    result
  end

  @doc """
  Updates a task.
  """
  def update_task(%Task{} = task, attrs) do
    result =
      task
      |> Task.changeset(attrs)
      |> Repo.update()

    with {:ok, _task} <- result, do: broadcast_tasks_changed()
    result
  end

  @doc """
  Updates just the status of a task.
  """
  def update_task_status(%Task{} = task, status)
      when status in [:pending, :executing, :completed, :failed] do
    result =
      task
      |> Ecto.Changeset.change(status: status)
      |> Repo.update()

    with {:ok, task} <- result do
      broadcast_tasks_changed()
      {:ok, Repo.preload(task, :steps)}
    end
  end

  @doc """
  Updates fields on a single task step.
  """
  def update_step(%TaskStep{} = step, attrs) do
    result =
      step
      |> Ecto.Changeset.change(attrs)
      |> Repo.update()

    with {:ok, _step} <- result, do: broadcast_tasks_changed()
    result
  end

  @doc """
  Deletes a task.
  """
  def delete_task(%Task{} = task) do
    result = Repo.delete(task)
    with {:ok, _task} <- result, do: broadcast_tasks_changed()
    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.
  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  @doc """
  Drives the task pipeline one step forward.

  Advances every executing task based on its current step's Oban job state,
  then starts the next runnable pending task whose devices are all idle.
  """
  def run_scheduler do
    Enum.each(list_tasks_by_status(:executing), &advance_task/1)
    start_next_runnable_task()
    :ok
  end

  defp start_next_runnable_task do
    case Enum.find(list_runnable_tasks(), &task_devices_available?/1) do
      nil -> :ok
      task -> start_task(task)
    end
  end

  defp start_task(task) do
    with {:ok, task} <- update_task_status(task, :executing) do
      progress_task(task)
    end
  end

  defp advance_task(task) do
    case Enum.find(task.steps, &(&1.status == :executing)) do
      nil -> progress_task(task)
      step -> check_step_job(task, step)
    end
  end

  defp check_step_job(task, step) do
    case step.job_id && Repo.get(Oban.Job, step.job_id) do
      %Oban.Job{state: "completed"} ->
        {:ok, _step} = update_step(step, status: :completed, job_id: nil)
        progress_task(reload_task(task))

      %Oban.Job{state: state} when state in ["discarded", "cancelled"] ->
        {:ok, _step} = update_step(step, status: :failed, job_id: nil)
        progress_task(reload_task(task))

      nil when not is_nil(step.job_id) ->
        {:ok, _step} = update_step(step, status: :failed, job_id: nil)
        progress_task(reload_task(task))

      _ ->
        :ok
    end
  end

  defp reload_task(task), do: get_task!(task.id)

  defp progress_task(task) do
    cond do
      Enum.any?(task.steps, &(&1.status == :failed)) ->
        update_task_status(task, :failed)

      Enum.all?(task.steps, &(&1.status == :completed)) ->
        update_task_status(task, :completed)

      true ->
        enqueue_next_pending_step(task)
    end
  end

  defp enqueue_next_pending_step(task) do
    case Enum.find(task.steps, &(&1.status == :pending)) do
      nil ->
        update_task_status(task, :completed)

      step ->
        with {:ok, job} <- enqueue_step_job(step) do
          update_step(step, status: :executing, job_id: job.id)
        end
    end
  end

  defp enqueue_step_job(%TaskStep{type: :flow} = step) do
    device = Inventory.get_device!(step.device_id)

    step.data
    |> Map.take(["maestro_flow", "maestro_arguments"])
    |> Map.put("maestro_platform", Device.platform(device))
    |> MaestroFlowWorker.new(queue: Device.queue_name(device))
    |> Oban.insert()
  end

  @doc """
  Returns true when every device referenced by the task has no active Oban jobs
  (scheduled, available, executing, or retryable) on its dedicated queue.
  """
  def task_devices_available?(%Task{} = task) do
    case task_queue_names(task) do
      [] ->
        true

      queues ->
        count =
          Repo.one(
            from j in Oban.Job,
              where: j.queue in ^queues and j.state in @active_job_states,
              select: count(j.id)
          )

        count == 0
    end
  end

  defp task_queue_names(task) do
    task.steps
    |> Enum.map(& &1.device_id)
    |> Enum.uniq()
    |> Enum.map(&Inventory.get_device!/1)
    |> Enum.map(fn %Device{name: name} -> "device:" <> name end)
  end
end
