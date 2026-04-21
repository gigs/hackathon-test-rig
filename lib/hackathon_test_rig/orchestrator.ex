defmodule HackathonTestRig.Orchestrator do
  @moduledoc """
  The Orchestrator context.

  Owns tasks: scheduled bundles of Maestro flows to run across devices.
  """

  import Ecto.Query, warn: false
  alias HackathonTestRig.Repo
  alias HackathonTestRig.Orchestrator.Task

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
end
