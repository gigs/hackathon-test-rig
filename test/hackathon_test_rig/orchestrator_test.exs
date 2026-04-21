defmodule HackathonTestRig.OrchestratorTest do
  use HackathonTestRig.DataCase

  alias HackathonTestRig.Orchestrator
  alias HackathonTestRig.Orchestrator.Task

  import HackathonTestRig.OrchestratorFixtures

  describe "tasks" do
    test "list_tasks/0 returns all tasks" do
      task = task_fixture()
      assert [listed] = Orchestrator.list_tasks()
      assert listed.id == task.id
    end

    test "get_task!/1 returns the task with given id" do
      task = task_fixture()
      assert Orchestrator.get_task!(task.id).id == task.id
    end

    test "create_task/1 with valid data creates a task" do
      step = step_attrs()

      attrs = %{
        steps: [step],
        maximum_execution_time: 120,
        scheduled_time: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:ok, %Task{} = task} = Orchestrator.create_task(attrs)
      assert task.maximum_execution_time == 120
      assert task.status == :pending
      assert [created_step] = task.steps
      assert created_step.type == :flow
      assert created_step.device_id == step.device_id
      assert created_step.data == step.data
    end

    test "create_task/1 with no steps returns an error changeset" do
      attrs = %{
        steps: [],
        maximum_execution_time: 120,
        scheduled_time: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Orchestrator.create_task(attrs)
      assert %{steps: _} = errors_on(changeset)
    end

    test "create_task/1 with invalid step returns an error changeset" do
      attrs = %{
        steps: [%{type: :flow, device_id: nil, maximum_execution_time: 0, data: %{}}],
        maximum_execution_time: 120,
        scheduled_time: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:error, %Ecto.Changeset{}} = Orchestrator.create_task(attrs)
    end

    test "create_task/1 with invalid top-level data returns an error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Orchestrator.create_task(%{
                 steps: nil,
                 maximum_execution_time: nil,
                 scheduled_time: nil
               })
    end

    test "update_task_status/2 transitions the task status" do
      task = task_fixture()
      assert {:ok, %Task{status: :executing}} = Orchestrator.update_task_status(task, :executing)
    end

    test "list_tasks_by_status/1 filters by status" do
      pending = task_fixture()
      other = task_fixture()
      {:ok, _} = Orchestrator.update_task_status(other, :completed)

      assert [%Task{id: id}] = Orchestrator.list_tasks_by_status(:pending)
      assert id == pending.id
    end

    test "delete_task/1 deletes the task" do
      task = task_fixture()
      assert {:ok, %Task{}} = Orchestrator.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Orchestrator.get_task!(task.id) end
    end

    test "change_task/1 returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = Orchestrator.change_task(task)
    end
  end
end
