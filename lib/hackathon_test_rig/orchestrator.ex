defmodule HackathonTestRig.Orchestrator do
  @moduledoc """
  The Orchestrator context.

  Owns tasks: scheduled bundles of Maestro flows to run across devices.
  """

  import Ecto.Query, warn: false
  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Inventory.Device
  alias HackathonTestRig.Orchestrator.Task
  alias HackathonTestRig.Repo
  alias HackathonTestRig.Workers.MaestroFlowWorker

  @active_job_states ~w(scheduled available executing retryable)

  @doc """
  Returns the list of tasks.
  """
  def list_tasks do
    Repo.all(from t in Task, order_by: [asc: t.scheduled_time])
  end

  @doc """
  Returns tasks with the given status.
  """
  def list_tasks_by_status(status) when status in [:pending, :executing, :completed, :failed] do
    Repo.all(from t in Task, where: t.status == ^status, order_by: [asc: t.scheduled_time])
  end

  @doc """
  Returns pending tasks whose scheduled time has arrived, ordered by scheduled_time.
  """
  def list_runnable_tasks(now \\ DateTime.utc_now()) do
    Repo.all(
      from t in Task,
        where: t.status == :pending and t.scheduled_time <= ^now,
        order_by: [asc: t.scheduled_time]
    )
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.
  """
  def get_task!(id), do: Repo.get!(Task, id)

  @doc """
  Creates a task.
  """
  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task.
  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates just the status of a task.
  """
  def update_task_status(%Task{} = task, status)
      when status in [:pending, :executing, :completed, :failed] do
    task
    |> Ecto.Changeset.change(status: status)
    |> Repo.update()
  end

  @doc """
  Updates fields on a single embedded flow at the given index.
  """
  def update_flow(%Task{} = task, index, flow_attrs) when is_integer(index) do
    updated_flows =
      List.update_at(task.flows, index, fn flow -> struct!(flow, flow_attrs) end)

    task
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_embed(:flows, updated_flows)
    |> Repo.update()
  end

  @doc """
  Deletes a task.
  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.
  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  @doc """
  Drives the task pipeline one step forward.

  Advances every executing task based on its current flow's Oban job state,
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
    case find_executing_flow(task) do
      {flow, index} -> check_flow_job(task, flow, index)
      nil -> progress_task(task)
    end
  end

  defp find_executing_flow(task) do
    task.flows
    |> Enum.with_index()
    |> Enum.find(fn {flow, _} -> flow.status == :executing end)
  end

  defp check_flow_job(task, flow, index) do
    case flow.job_id && Repo.get(Oban.Job, flow.job_id) do
      %Oban.Job{state: "completed"} ->
        {:ok, task} = update_flow(task, index, status: :completed, job_id: nil)
        progress_task(task)

      %Oban.Job{state: state} when state in ["discarded", "cancelled"] ->
        {:ok, task} = update_flow(task, index, status: :failed, job_id: nil)
        progress_task(task)

      _ ->
        :ok
    end
  end

  defp progress_task(task) do
    cond do
      Enum.any?(task.flows, &(&1.status == :failed)) ->
        update_task_status(task, :failed)

      Enum.all?(task.flows, &(&1.status == :completed)) ->
        update_task_status(task, :completed)

      true ->
        enqueue_next_pending_flow(task)
    end
  end

  defp enqueue_next_pending_flow(task) do
    case pending_flow(task) do
      nil ->
        update_task_status(task, :completed)

      {flow, index} ->
        with {:ok, job} <- enqueue_flow_job(flow) do
          update_flow(task, index, status: :executing, job_id: job.id)
        end
    end
  end

  defp pending_flow(task) do
    task.flows
    |> Enum.with_index()
    |> Enum.find(fn {flow, _} -> flow.status == :pending end)
  end

  defp enqueue_flow_job(flow) do
    device = Inventory.get_device!(flow.device_id)

    %{
      "maestro_flow" => flow.maestro_flow,
      "maestro_arguments" => flow.maestro_arguments
    }
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
    task.flows
    |> Enum.map(& &1.device_id)
    |> Enum.uniq()
    |> Enum.map(&Inventory.get_device!/1)
    |> Enum.map(fn %Device{name: name} -> "device:" <> name end)
  end
end
