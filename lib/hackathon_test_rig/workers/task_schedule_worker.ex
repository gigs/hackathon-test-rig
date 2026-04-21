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
    max_attempts: 1,
    unique: [states: [:available, :scheduled, :executing, :retryable]]

  require Logger

  alias HackathonTestRig.Orchestrator

  @poll_interval_seconds 10

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    try do
      Orchestrator.run_scheduler()
    rescue
      error ->
        Logger.error("TaskScheduleWorker tick failed: #{Exception.message(error)}")
    after
      schedule_next_tick()
    end

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
    # Uniqueness is disabled here because this insert happens while the current
    # job is still :executing, which would otherwise dedup the next tick against
    # the currently-running one. The :scheduler queue has concurrency 1, so
    # ticks serialize naturally; the Cron plugin keeps uniqueness enabled and
    # acts as a safety net if the self-reschedule ever fails.
    %{} |> new(schedule_in: @poll_interval_seconds, unique: false) |> Oban.insert()
  end
end
