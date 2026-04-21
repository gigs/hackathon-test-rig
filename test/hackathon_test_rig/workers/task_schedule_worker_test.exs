defmodule HackathonTestRig.Workers.TaskScheduleWorkerTest do
  use HackathonTestRig.DataCase

  use Oban.Testing, repo: HackathonTestRig.Repo

  alias HackathonTestRig.Inventory.Device
  alias HackathonTestRig.Orchestrator
  alias HackathonTestRig.Orchestrator.Task
  alias HackathonTestRig.Workers.MaestroFlowWorker
  alias HackathonTestRig.Workers.TaskScheduleWorker

  import HackathonTestRig.InventoryFixtures
  import HackathonTestRig.OrchestratorFixtures

  describe "perform/1" do
    test "no-ops and re-schedules when no tasks exist" do
      assert :ok = perform_job(TaskScheduleWorker, %{})
      assert_enqueued(worker: TaskScheduleWorker, queue: :scheduler)
    end

    test "starts the next runnable task and enqueues its first step" do
      device = device_fixture()
      task = task_fixture(%{steps: [step_attrs(%{device_id: device.id})]})

      assert :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :executing
      assert [%{status: :executing, job_id: job_id}] = task.steps
      assert is_integer(job_id)

      assert_enqueued(worker: MaestroFlowWorker, queue: Device.queue_name(device))
    end

    test "skips a task whose device queue already has active jobs" do
      device = device_fixture()
      task = task_fixture(%{steps: [step_attrs(%{device_id: device.id})]})

      {:ok, _} =
        MaestroFlowWorker.new(%{"maestro_flow" => "x", "maestro_arguments" => %{}},
          queue: Device.queue_name(device)
        )
        |> Oban.insert()

      assert :ok = perform_job(TaskScheduleWorker, %{})

      assert %Task{status: :pending, steps: [%{status: :pending}]} =
               Orchestrator.get_task!(task.id)
    end

    test "advances to the next step when the current step's job completed" do
      device = device_fixture()

      task =
        task_fixture(%{
          steps: [
            step_attrs(%{device_id: device.id}),
            step_attrs(%{device_id: device.id})
          ]
        })

      :ok = perform_job(TaskScheduleWorker, %{})

      [first_step, _] = Orchestrator.get_task!(task.id).steps
      set_job_state(first_step.job_id, "completed")

      :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :executing
      assert [%{status: :completed}, %{status: :executing, job_id: second_job_id}] = task.steps
      assert is_integer(second_job_id)
    end

    test "marks task as completed when the final step completes" do
      device = device_fixture()
      task = task_fixture(%{steps: [step_attrs(%{device_id: device.id})]})

      :ok = perform_job(TaskScheduleWorker, %{})

      [step] = Orchestrator.get_task!(task.id).steps
      set_job_state(step.job_id, "completed")

      :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :completed
      assert [%{status: :completed}] = task.steps
    end

    test "marks task as failed when a step's job was discarded" do
      device = device_fixture()

      task =
        task_fixture(%{
          steps: [
            step_attrs(%{device_id: device.id}),
            step_attrs(%{device_id: device.id})
          ]
        })

      :ok = perform_job(TaskScheduleWorker, %{})

      [first_step, _] = Orchestrator.get_task!(task.id).steps
      set_job_state(first_step.job_id, "discarded")

      :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :failed
      assert [%{status: :failed}, %{status: :pending}] = task.steps

      refute_enqueued(
        worker: MaestroFlowWorker,
        queue: Device.queue_name(device),
        args: %{"maestro_flow" => Enum.at(task.steps, 1).data["maestro_flow"]}
      )
    end

    test "does not start tasks whose scheduled time is still in the future" do
      device = device_fixture()
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      task =
        task_fixture(%{
          scheduled_time: future,
          steps: [step_attrs(%{device_id: device.id})]
        })

      :ok = perform_job(TaskScheduleWorker, %{})

      assert %Task{status: :pending} = Orchestrator.get_task!(task.id)
    end
  end

  defp set_job_state(job_id, state) do
    Oban.Job
    |> Repo.get!(job_id)
    |> Ecto.Changeset.change(state: state)
    |> Repo.update!()
  end
end
