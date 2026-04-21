defmodule HackathonTestRig.InventoryTest do
  use HackathonTestRig.DataCase

  alias HackathonTestRig.Inventory

  describe "test_rigs" do
    alias HackathonTestRig.Inventory.TestRig

    import HackathonTestRig.InventoryFixtures

    @invalid_attrs %{name: nil, location: nil, hostname: nil}

    test "list_test_rigs/0 returns all test_rigs" do
      test_rig = test_rig_fixture()
      assert Inventory.list_test_rigs() == [test_rig]
    end

    test "get_test_rig!/1 returns the test_rig with given id" do
      test_rig = test_rig_fixture()
      assert Inventory.get_test_rig!(test_rig.id) == test_rig
    end

    test "create_test_rig/1 with valid data creates a test_rig" do
      valid_attrs = %{name: "some name", location: "some location", hostname: "some hostname"}

      assert {:ok, %TestRig{} = test_rig} = Inventory.create_test_rig(valid_attrs)
      assert test_rig.name == "some name"
      assert test_rig.location == "some location"
      assert test_rig.hostname == "some hostname"
    end

    test "create_test_rig/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Inventory.create_test_rig(@invalid_attrs)
    end

    test "update_test_rig/2 with valid data updates the test_rig" do
      test_rig = test_rig_fixture()
      update_attrs = %{name: "some updated name", location: "some updated location", hostname: "some updated hostname"}

      assert {:ok, %TestRig{} = test_rig} = Inventory.update_test_rig(test_rig, update_attrs)
      assert test_rig.name == "some updated name"
      assert test_rig.location == "some updated location"
      assert test_rig.hostname == "some updated hostname"
    end

    test "update_test_rig/2 with invalid data returns error changeset" do
      test_rig = test_rig_fixture()
      assert {:error, %Ecto.Changeset{}} = Inventory.update_test_rig(test_rig, @invalid_attrs)
      assert test_rig == Inventory.get_test_rig!(test_rig.id)
    end

    test "delete_test_rig/1 deletes the test_rig" do
      test_rig = test_rig_fixture()
      assert {:ok, %TestRig{}} = Inventory.delete_test_rig(test_rig)
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_test_rig!(test_rig.id) end
    end

    test "change_test_rig/1 returns a test_rig changeset" do
      test_rig = test_rig_fixture()
      assert %Ecto.Changeset{} = Inventory.change_test_rig(test_rig)
    end
  end

  describe "devices" do
    alias HackathonTestRig.Inventory.Device

    import HackathonTestRig.InventoryFixtures

    @invalid_attrs %{name: nil, brand: nil, type: nil}

    test "list_devices/0 returns all devices" do
      device = device_fixture()
      assert Inventory.list_devices() == [device]
    end

    test "get_device!/1 returns the device with given id" do
      device = device_fixture()
      assert Inventory.get_device!(device.id) == device
    end

    test "create_device/1 with valid data creates a device" do
      test_rig = test_rig_fixture()
      valid_attrs = %{name: "some name", brand: "some brand", type: :smartphone, test_rig_id: test_rig.id}

      assert {:ok, %Device{} = device} = Inventory.create_device(valid_attrs)
      assert device.name == "some name"
      assert device.brand == "some brand"
      assert device.type == :smartphone
      assert device.test_rig_id == test_rig.id
    end

    test "create_device/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Inventory.create_device(@invalid_attrs)
    end

    test "update_device/2 with valid data updates the device" do
      device = device_fixture()
      update_attrs = %{name: "some updated name", brand: "some updated brand", type: :tablet}

      assert {:ok, %Device{} = device} = Inventory.update_device(device, update_attrs)
      assert device.name == "some updated name"
      assert device.brand == "some updated brand"
      assert device.type == :tablet
    end

    test "update_device/2 with invalid data returns error changeset" do
      device = device_fixture()
      assert {:error, %Ecto.Changeset{}} = Inventory.update_device(device, @invalid_attrs)
      assert device == Inventory.get_device!(device.id)
    end

    test "delete_device/1 deletes the device" do
      device = device_fixture()
      assert {:ok, %Device{}} = Inventory.delete_device(device)
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_device!(device.id) end
    end

    test "change_device/1 returns a device changeset" do
      device = device_fixture()
      assert %Ecto.Changeset{} = Inventory.change_device(device)
    end
  end
end
