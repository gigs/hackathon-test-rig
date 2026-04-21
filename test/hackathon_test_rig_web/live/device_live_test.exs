defmodule HackathonTestRigWeb.DeviceLiveTest do
  use HackathonTestRigWeb.ConnCase

  import Phoenix.LiveViewTest
  import HackathonTestRig.InventoryFixtures
  import HackathonTestRig.OrchestratorFixtures

  @invalid_attrs %{name: nil, brand: nil, type: nil, test_rig_id: nil}
  defp create_device(_) do
    device = device_fixture()

    %{device: device}
  end

  defp create_attrs(test_rig_id) do
    %{
      name: "some name",
      brand: "Apple",
      type: :smartphone,
      test_rig_id: test_rig_id
    }
  end

  defp update_attrs(test_rig_id) do
    %{
      name: "some updated name",
      brand: "Google",
      type: :tablet,
      test_rig_id: test_rig_id
    }
  end

  # The flow_yaml textarea only renders when a step's template is "custom".
  # This switches the given step to custom so subsequent form/3 calls can find it.
  defp switch_step_to_custom(show_live, step_id) do
    show_live
    |> form("#schedule-task-form",
      maestro: %{"steps" => %{step_id => %{"flow_template" => "custom"}}}
    )
    |> render_change()
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

      switch_step_to_custom(show_live, "0")

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "steps" => %{
          "0" => %{
            "flow_template" => "custom",
            "flow_yaml" => "appId: com.example\n---\n- launchApp",
            "arguments" => %{"0" => %{"key" => "user", "value" => "alice"}}
          }
        }
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
      assert step.data["maestro_flow"] == params["steps"]["0"]["flow_yaml"]
      assert step.data["maestro_arguments"] == %{"user" => "alice"}
    end

    test "scheduling a multi-step task persists steps in order", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      # Second step card.
      show_live |> element("button[phx-click=\"add_step\"]") |> render_click()
      switch_step_to_custom(show_live, "0")
      switch_step_to_custom(show_live, "1")

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "steps" => %{
          "0" => %{
            "flow_template" => "custom",
            "flow_yaml" => "appId: com.first",
            "arguments" => %{"0" => %{"key" => "STAGE", "value" => "one"}}
          },
          "1" => %{
            "flow_template" => "custom",
            "flow_yaml" => "appId: com.second",
            "arguments" => %{"0" => %{"key" => "STAGE", "value" => "two"}}
          }
        }
      }

      show_live
      |> form("#schedule-task-form", maestro: params)
      |> render_submit()

      [task] = HackathonTestRig.Orchestrator.list_tasks_for_device(device.id)
      assert [first, second] = task.steps
      assert first.data["maestro_flow"] == "appId: com.first"
      assert first.data["maestro_arguments"] == %{"STAGE" => "one"}
      assert second.data["maestro_flow"] == "appId: com.second"
      assert second.data["maestro_arguments"] == %{"STAGE" => "two"}
    end

    test "removing a step drops it from the form", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      show_live |> element("button[phx-click=\"add_step\"]") |> render_click()
      assert has_element?(show_live, "[data-step-id=\"1\"]")

      show_live
      |> element("button[phx-click=\"remove_step\"][phx-value-id=\"1\"]")
      |> render_click()

      refute has_element?(show_live, "[data-step-id=\"1\"]")
    end

    test "scheduling fails when flow YAML is blank", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      switch_step_to_custom(show_live, "0")

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "steps" => %{
          "0" => %{
            "flow_template" => "custom",
            "flow_yaml" => "",
            "arguments" => %{"0" => %{"key" => "", "value" => ""}}
          }
        }
      }

      html =
        show_live
        |> form("#schedule-task-form", maestro: params)
        |> render_submit()

      assert html =~ "Flow YAML can&#39;t be blank."
      assert HackathonTestRig.Orchestrator.list_tasks_for_device(device.id) == []
    end

    test "adding and removing argument rows works", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      # Starts with a single blank row.
      assert has_element?(show_live, "input[name=\"maestro[steps][0][arguments][0][key]\"]")
      refute has_element?(show_live, "input[name=\"maestro[steps][0][arguments][1][key]\"]")

      show_live
      |> element("button[phx-click=\"add_arg_pair\"][phx-value-step=\"0\"]")
      |> render_click()

      assert has_element?(show_live, "input[name=\"maestro[steps][0][arguments][1][key]\"]")

      show_live
      |> element(
        "button[phx-click=\"remove_arg_pair\"][phx-value-step=\"0\"][phx-value-index=\"1\"]"
      )
      |> render_click()

      refute has_element?(show_live, "input[name=\"maestro[steps][0][arguments][1][key]\"]")
    end

    test "pasting env vars replaces blank rows with parsed pairs", %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      render_hook(show_live, "bulk_paste_args", %{
        "step" => "0",
        "index" => 0,
        "pairs" => [
          %{"key" => "USER", "value" => "alice"},
          %{"key" => "TOKEN", "value" => "s3cret"}
        ]
      })

      html = render(show_live)
      assert html =~ "value=\"USER\""
      assert html =~ "value=\"alice\""
      assert html =~ "value=\"TOKEN\""
      assert html =~ "value=\"s3cret\""
    end

    test "typing yaml adds argument rows for referenced ${VARS}, skipping escapes",
         %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      switch_step_to_custom(show_live, "0")

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "steps" => %{
          "0" => %{
            "flow_template" => "custom",
            "flow_yaml" =>
              "appId: ${APP_ID}\n---\n- inputText: \"hello ${USERNAME}\"\n- runScript: \"\\${NOT_A_VAR}\"",
            "arguments" => %{"0" => %{"key" => "", "value" => ""}}
          }
        }
      }

      html =
        show_live
        |> form("#schedule-task-form", maestro: params)
        |> render_change()

      assert html =~ ~s(value="APP_ID")
      assert html =~ ~s(value="USERNAME")
      refute html =~ ~s(value="NOT_A_VAR")
    end

    test "extracted vars do not overwrite existing user-entered keys or values",
         %{conn: conn, device: device} do
      {:ok, show_live, _html} = live(conn, ~p"/devices/#{device}")

      switch_step_to_custom(show_live, "0")

      params = %{
        "scheduled_time" => "2026-04-21T15:30",
        "maximum_execution_time" => "120",
        "steps" => %{
          "0" => %{
            "flow_template" => "custom",
            "flow_yaml" => "appId: ${APP_ID}",
            "arguments" => %{"0" => %{"key" => "APP_ID", "value" => "com.example"}}
          }
        }
      }

      html =
        show_live
        |> form("#schedule-task-form", maestro: params)
        |> render_change()

      assert html =~ ~s(value="APP_ID")
      assert html =~ ~s(value="com.example")
      refute has_element?(show_live, "input[name=\"maestro[steps][0][arguments][1][key]\"]")
    end

    test "shows the currently running step under an executing task", %{
      conn: conn,
      device: device
    } do
      task =
        task_fixture(%{
          status: :executing,
          steps: [
            step_attrs(%{
              device_id: device.id,
              status: :completed,
              data: %{
                "maestro_flow" => "appId: com.first\n---\n- launchApp",
                "maestro_arguments" => %{}
              }
            }),
            step_attrs(%{
              device_id: device.id,
              status: :executing,
              data: %{
                "maestro_flow" => "appId: com.running.app\n---\n- launchApp",
                "maestro_arguments" => %{}
              }
            }),
            step_attrs(%{device_id: device.id, status: :pending})
          ]
        })

      {:ok, show_live, html} = live(conn, ~p"/devices/#{device}")

      assert html =~ "Running step 2 of 3"
      assert html =~ "com.running.app"
      assert has_element?(show_live, "#tasks-#{task.id}-running-step")
    end

    test "does not show a running step for pending tasks", %{conn: conn, device: device} do
      task_fixture(%{steps: [step_attrs(%{device_id: device.id})]})

      {:ok, _show_live, html} = live(conn, ~p"/devices/#{device}")

      refute html =~ "Running step"
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
