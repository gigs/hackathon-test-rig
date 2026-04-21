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

  describe "phones" do
    alias HackathonTestRig.Inventory.Phone

    import HackathonTestRig.InventoryFixtures

    @invalid_attrs %{name: nil, os_version: nil, type: nil, device_model: nil}

    test "list_phones/0 returns all phones" do
      phone = phone_fixture()
      assert Inventory.list_phones() == [phone]
    end

    test "get_phone!/1 returns the phone with given id" do
      phone = phone_fixture()
      assert Inventory.get_phone!(phone.id) == phone
    end

    test "create_phone/1 with valid data creates a phone" do
      test_rig = test_rig_fixture()
      valid_attrs = %{name: "some name", os_version: "some os_version", type: :android, device_model: "some device_model", test_rig_id: test_rig.id}

      assert {:ok, %Phone{} = phone} = Inventory.create_phone(valid_attrs)
      assert phone.name == "some name"
      assert phone.os_version == "some os_version"
      assert phone.type == :android
      assert phone.device_model == "some device_model"
      assert phone.test_rig_id == test_rig.id
    end

    test "create_phone/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Inventory.create_phone(@invalid_attrs)
    end

    test "update_phone/2 with valid data updates the phone" do
      phone = phone_fixture()
      update_attrs = %{name: "some updated name", os_version: "some updated os_version", type: :ios, device_model: "some updated device_model"}

      assert {:ok, %Phone{} = phone} = Inventory.update_phone(phone, update_attrs)
      assert phone.name == "some updated name"
      assert phone.os_version == "some updated os_version"
      assert phone.type == :ios
      assert phone.device_model == "some updated device_model"
    end

    test "update_phone/2 with invalid data returns error changeset" do
      phone = phone_fixture()
      assert {:error, %Ecto.Changeset{}} = Inventory.update_phone(phone, @invalid_attrs)
      assert phone == Inventory.get_phone!(phone.id)
    end

    test "delete_phone/1 deletes the phone" do
      phone = phone_fixture()
      assert {:ok, %Phone{}} = Inventory.delete_phone(phone)
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_phone!(phone.id) end
    end

    test "change_phone/1 returns a phone changeset" do
      phone = phone_fixture()
      assert %Ecto.Changeset{} = Inventory.change_phone(phone)
    end
  end
end
