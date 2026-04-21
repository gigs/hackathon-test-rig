defmodule HackathonTestRig.Workers.TaskScheduleWorker do
  @moduledoc """
  Singleton scheduler that polls the orchestrator every 10 seconds.

  On each tick it advances tasks already executing (inspecting the Oban job
  state of each task's current flow) and starts the next runnable pending task
  whose devices are all idle. The worker re-schedules itself after every run,
  so a single enqueued job keeps the pipeline ticking.
  """

  use Oban.Worker,
    queue: :scheduler,
    max_attempts: 3,
    unique: [states: [:available, :scheduled, :executing, :retryable]]

  alias HackathonTestRig.Orchestrator

  @poll_interval_seconds 10

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Orchestrator.run_scheduler()
    schedule_next_tick()
    :ok
  end

  @doc """
  Ensures a scheduler job is in the queue. The worker's uniqueness config
  means repeat calls are a no-op while one is already queued or running.
  """
  def ensure_scheduled do
    %{} |> new() |> Oban.insert()
  end

  defp schedule_next_tick do
    %{} |> new(schedule_in: @poll_interval_seconds) |> Oban.insert()
  end
end
