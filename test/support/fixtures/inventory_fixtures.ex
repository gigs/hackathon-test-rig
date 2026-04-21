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
        location: "some location",
        name: "some name"
      })
      |> HackathonTestRig.Inventory.create_test_rig()

    test_rig
  end

  @doc """
  Generate a phone.
  """
  def phone_fixture(attrs \\ %{}) do
    test_rig_id = Map.get_lazy(attrs, :test_rig_id, fn -> test_rig_fixture().id end)

    {:ok, phone} =
      attrs
      |> Enum.into(%{
        device_model: "some device_model",
        name: "some name",
        os_version: "some os_version",
        type: :android,
        test_rig_id: test_rig_id
      })
      |> HackathonTestRig.Inventory.create_phone()

    HackathonTestRig.Inventory.get_phone!(phone.id)
  end
end
