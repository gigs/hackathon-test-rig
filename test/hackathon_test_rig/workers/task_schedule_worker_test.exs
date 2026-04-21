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
      assert_enqueued worker: TaskScheduleWorker, queue: :scheduler
    end

    test "starts the next runnable task and enqueues its first flow" do
      device = device_fixture()
      task = task_fixture(%{flows: [flow_attrs(%{device_id: device.id})]})

      assert :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :executing
      assert [%{status: :executing, job_id: job_id}] = task.flows
      assert is_integer(job_id)

      assert_enqueued worker: MaestroFlowWorker, queue: Device.queue_name(device)
    end

    test "skips a task whose device queue already has active jobs" do
      device = device_fixture()
      task = task_fixture(%{flows: [flow_attrs(%{device_id: device.id})]})

      {:ok, _} =
        MaestroFlowWorker.new(%{"maestro_flow" => "x", "maestro_arguments" => %{}},
          queue: Device.queue_name(device)
        )
        |> Oban.insert()

      assert :ok = perform_job(TaskScheduleWorker, %{})

      assert %Task{status: :pending, flows: [%{status: :pending}]} =
               Orchestrator.get_task!(task.id)
    end

    test "advances to the next flow when the current flow's job completed" do
      device = device_fixture()

      task =
        task_fixture(%{
          flows: [
            flow_attrs(%{device_id: device.id}),
            flow_attrs(%{device_id: device.id})
          ]
        })

      :ok = perform_job(TaskScheduleWorker, %{})

      [first_flow, _] = Orchestrator.get_task!(task.id).flows
      set_job_state(first_flow.job_id, "completed")

      :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :executing
      assert [%{status: :completed}, %{status: :executing, job_id: second_job_id}] = task.flows
      assert is_integer(second_job_id)
    end

    test "marks task as completed when the final flow completes" do
      device = device_fixture()
      task = task_fixture(%{flows: [flow_attrs(%{device_id: device.id})]})

      :ok = perform_job(TaskScheduleWorker, %{})

      [flow] = Orchestrator.get_task!(task.id).flows
      set_job_state(flow.job_id, "completed")

      :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :completed
      assert [%{status: :completed}] = task.flows
    end

    test "marks task as failed when a flow's job was discarded" do
      device = device_fixture()

      task =
        task_fixture(%{
          flows: [
            flow_attrs(%{device_id: device.id}),
            flow_attrs(%{device_id: device.id})
          ]
        })

      :ok = perform_job(TaskScheduleWorker, %{})

      [first_flow, _] = Orchestrator.get_task!(task.id).flows
      set_job_state(first_flow.job_id, "discarded")

      :ok = perform_job(TaskScheduleWorker, %{})

      task = Orchestrator.get_task!(task.id)
      assert task.status == :failed
      assert [%{status: :failed}, %{status: :pending}] = task.flows

      refute_enqueued(
        worker: MaestroFlowWorker,
        queue: Device.queue_name(device),
        args: %{"maestro_flow" => Enum.at(task.flows, 1).maestro_flow}
      )
    end

    test "does not start tasks whose scheduled time is still in the future" do
      device = device_fixture()
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      task =
        task_fixture(%{
          scheduled_time: future,
          flows: [flow_attrs(%{device_id: device.id})]
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
