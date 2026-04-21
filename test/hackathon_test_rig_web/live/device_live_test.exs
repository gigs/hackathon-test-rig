defmodule HackathonTestRigWeb.DeviceLiveTest do
  use HackathonTestRigWeb.ConnCase

  import Phoenix.LiveViewTest
  import HackathonTestRig.InventoryFixtures

  @invalid_attrs %{name: nil, brand: nil, type: nil, test_rig_id: nil}
  defp create_device(_) do
    device = device_fixture()

    %{device: device}
  end

  defp create_attrs(test_rig_id) do
    %{
      name: "some name",
      brand: "some brand",
      type: :smartphone,
      test_rig_id: test_rig_id
    }
  end

  defp update_attrs(test_rig_id) do
    %{
      name: "some updated name",
      brand: "some updated brand",
      type: :tablet,
      test_rig_id: test_rig_id
    }
  end

  describe "Index" do
    setup [:create_device]

    test "lists all devices", %{conn: conn, device: device} do
      {:ok, _index_live, html} = live(conn, ~p"/devices")

      assert html =~ "Listing Devices"
      assert html =~ device.name
    end

    test "saves new device", %{conn: conn} do
      test_rig = test_rig_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/devices")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Device")
               |> render_click()
               |> follow_redirect(conn, ~p"/devices/new")

      assert render(form_live) =~ "New Device"

      assert form_live
             |> form("#device-form", device: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#device-form", device: create_attrs(test_rig.id))
               |> render_submit()
               |> follow_redirect(conn, ~p"/devices")

      html = render(index_live)
      assert html =~ "Device created successfully"
      assert html =~ "some name"
    end

    test "updates device in listing", %{conn: conn, device: device} do
      {:ok, index_live, _html} = live(conn, ~p"/devices")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#devices-#{device.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/devices/#{device}/edit")

      assert render(form_live) =~ "Edit Device"

      assert form_live
             |> form("#device-form", device: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#device-form", device: update_attrs(device.test_rig_id))
               |> render_submit()
               |> follow_redirect(conn, ~p"/devices")

      html = render(index_live)
      assert html =~ "Device updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes device in listing", %{conn: conn, device: device} do
      {:ok, index_live, _html} = live(conn, ~p"/devices")

      assert index_live |> element("#devices-#{device.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#devices-#{device.id}")
    end
  end

  describe "Show" do
    setup [:create_device]

    test "displays device", %{conn: conn, device: device} do
      {:ok, _show_live, html} = live(conn, ~p"/devices/#{device}")

      assert html =~ "Show Device"
      assert html =~ device.name
    end

    test "scheduling a task creates a pending task and shows it in history", %{
      conn: conn,
      device: device
    } do
      {:ok, show_live, html} = live(conn, ~p"/devices/#{device}")

      assert html =~ "No tasks scheduled yet."

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "flow_yaml" => "appId: com.example\n---\n- launchApp",
        "arguments_yaml" => "user: alice"
      }

      html =
        show_live
        |> form("#schedule-task-form", maestro: params)
        |> render_submit()

      assert html =~ "Task scheduled."
      assert html =~ "pending"
      refute html =~ "No tasks scheduled yet."

      [task] = HackathonTestRig.Orchestrator.list_tasks_for_device(device.id)
      assert task.maximum_execution_time == 120
      assert task.scheduled_time == ~U[2026-04-21 15:30:00Z]
      assert [step] = task.steps
      assert step.type == :flow
      assert step.device_id == device.id
      assert step.data["maestro_flow"] == params["flow_yaml"]
      assert step.data["maestro_arguments"] == %{"user" => "alice"}
    end

    test "scheduling fails when flow YAML is blank", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "flow_yaml" => "",
        "arguments_yaml" => ""
      }

      html =
        show_live
        |> form("#schedule-task-form", maestro: params)
        |> render_submit()

      assert html =~ "Flow YAML can&#39;t be blank."
      assert HackathonTestRig.Orchestrator.list_tasks_for_device(device.id) == []
    end

    test "updates device and returns to show", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/devices/#{device}/edit?return_to=show")

      assert render(form_live) =~ "Edit Device"

      assert form_live
             |> form("#device-form", device: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#device-form", device: update_attrs(device.test_rig_id))
               |> render_submit()
               |> follow_redirect(conn, ~p"/devices/#{device}")

      html = render(show_live)
      assert html =~ "Device updated successfully"
      assert html =~ "some updated name"
    end
  end
end
