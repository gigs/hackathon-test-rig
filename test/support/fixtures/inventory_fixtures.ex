defmodule HackathonTestRig.InventoryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HackathonTestRig.Inventory` context.
  """

  @doc """
  Generate a test_rig.
  """
  def test_rig_fixture(attrs \\ %{}) do
    {:ok, test_rig} =
      attrs
      |> Enum.into(%{
        hostname: "some hostname",
        location: "London, UK",
        name: "some name"
      })
      |> HackathonTestRig.Inventory.create_test_rig()

    test_rig
  end

  @doc """
  Generate a device.
  """
  def device_fixture(attrs \\ %{}) do
    test_rig_id = Map.get_lazy(attrs, :test_rig_id, fn -> test_rig_fixture().id end)

    {:ok, device} =
      attrs
      |> Enum.into(%{
        brand: "some brand",
        name: "some name",
        type: :smartphone,
        test_rig_id: test_rig_id
      })
      |> HackathonTestRig.Inventory.create_device()

    HackathonTestRig.Inventory.get_device!(device.id)
  end
end
