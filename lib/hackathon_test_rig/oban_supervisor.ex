defmodule HackathonTestRig.ObanSupervisor do
  @moduledoc """
  Boots Oban with one queue per device.

  Dynamic queues are an Oban Pro feature. Until we adopt that, we read the
  devices from the database at startup and hand Oban a fixed queue list built
  from them. Devices added after boot won't have a running queue until the
  application restarts.
  """

  alias HackathonTestRig.Inventory

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
    Oban.start_link(Keyword.put(base, :queues, queues(base)))
  end

  defp queues(base) do
    base_queues = Keyword.get(base, :queues, [])

    if Keyword.has_key?(base, :testing) do
      base_queues
    else
      base_queues ++ Inventory.oban_queues()
    end
  end
end
