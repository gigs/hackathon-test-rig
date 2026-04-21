defmodule HackathonTestRig.OrchestratorFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HackathonTestRig.Orchestrator` context.
  """

  import HackathonTestRig.InventoryFixtures

  @doc """
  Generate a task step attrs map.
  """
  def step_attrs(attrs \\ %{}) do
    device_id = Map.get_lazy(attrs, :device_id, fn -> device_fixture().id end)

    Enum.into(attrs, %{
      type: :flow,
      device_id: device_id,
      maximum_execution_time: 60,
      data: %{
        "maestro_flow" => "appId: com.example\n---\n- launchApp",
        "maestro_arguments" => %{"foo" => "bar"}
      }
    })
  end

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {steps_attrs, attrs} = Map.pop_lazy(attrs, :steps, fn -> [step_attrs()] end)

    {:ok, task} =
      attrs
      |> Enum.into(%{
        steps: steps_attrs,
        maximum_execution_time: 300,
        scheduled_time: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> HackathonTestRig.Orchestrator.create_task()

    task
  end
end
