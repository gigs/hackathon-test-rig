defmodule HackathonTestRig.ObanSupervisor do
  @moduledoc """
  Boots Oban with one queue per device.

  Dynamic queues are an Oban Pro feature. Until we adopt that, we read the
  devices from the database at startup and hand Oban a fixed queue list built
  from them. Devices added after boot won't have a running queue until the
  application restarts.
  """

  alias HackathonTestRig.Inventory
  alias HackathonTestRig.Workers.TaskScheduleWorker

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor,
      restart: :permanent
    }
  end

  def start_link do
    base = Application.fetch_env!(:hackathon_test_rig, Oban)

    opts =
      base
      |> Keyword.put(:queues, queues(base))
      |> Keyword.put(:plugins, plugins(base))

    with {:ok, pid} <- Oban.start_link(opts) do
      maybe_bootstrap_scheduler(base)
      {:ok, pid}
    end
  end

  defp queues(base) do
    base_queues = Keyword.get(base, :queues, [])

    if Keyword.has_key?(base, :testing) do
      base_queues
    else
      base_queues ++ Inventory.oban_queues()
    end
  end

  defp plugins(base) do
    base_plugins = Keyword.get(base, :plugins, [])

    if Keyword.has_key?(base, :testing) do
      base_plugins
    else
      base_plugins ++
        [
          {Oban.Plugins.Cron, crontab: [{"* * * * *", TaskScheduleWorker}]}
        ]
    end
  end

  defp maybe_bootstrap_scheduler(base) do
    unless Keyword.has_key?(base, :testing) do
      TaskScheduleWorker.ensure_scheduled()
    end
  end
end
