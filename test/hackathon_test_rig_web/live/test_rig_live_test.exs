defmodule HackathonTestRigWeb.TestRigLiveTest do
  use HackathonTestRigWeb.ConnCase

  import Phoenix.LiveViewTest
  import HackathonTestRig.InventoryFixtures

  @create_attrs %{name: "some name", location: "London, UK", hostname: "some hostname"}
  @update_attrs %{
    name: "some updated name",
    location: "Dublin, IE",
    hostname: "some updated hostname"
  }
  @invalid_attrs %{name: nil, location: nil, hostname: nil}
  defp create_test_rig(_) do
    test_rig = test_rig_fixture()

    %{test_rig: test_rig}
  end

  describe "Index" do
    setup [:create_test_rig]

    test "lists all test_rigs", %{conn: conn, test_rig: test_rig} do
      {:ok, _index_live, html} = live(conn, ~p"/test_rigs")

      assert html =~ "Listing Test rigs"
      assert html =~ test_rig.name
    end

    test "saves new test_rig", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/test_rigs")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Test rig")
               |> render_click()
               |> follow_redirect(conn, ~p"/test_rigs/new")

      assert render(form_live) =~ "New Test rig"

      assert form_live
             |> form("#test_rig-form", test_rig: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#test_rig-form", test_rig: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/test_rigs")

      html = render(index_live)
      assert html =~ "Test rig created successfully"
      assert html =~ "some name"
    end

    test "updates test_rig in listing", %{conn: conn, test_rig: test_rig} do
      {:ok, index_live, _html} = live(conn, ~p"/test_rigs")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#test_rigs-#{test_rig.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/test_rigs/#{test_rig}/edit")

      assert render(form_live) =~ "Edit Test rig"

      assert form_live
             |> form("#test_rig-form", test_rig: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#test_rig-form", test_rig: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/test_rigs")

      html = render(index_live)
      assert html =~ "Test rig updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes test_rig in listing", %{conn: conn, test_rig: test_rig} do
      {:ok, index_live, _html} = live(conn, ~p"/test_rigs")

      assert index_live |> element("#test_rigs-#{test_rig.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#test_rigs-#{test_rig.id}")
    end
  end

  describe "Show" do
    setup [:create_test_rig]

    test "displays test_rig", %{conn: conn, test_rig: test_rig} do
      {:ok, _show_live, html} = live(conn, ~p"/test_rigs/#{test_rig}")

      assert html =~ "Show Test rig"
      assert html =~ test_rig.name
    end

    test "updates test_rig and returns to show", %{conn: conn, test_rig: test_rig} do
      {:ok, show_live, _html} = live(conn, ~p"/test_rigs/#{test_rig}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/test_rigs/#{test_rig}/edit?return_to=show")

      assert render(form_live) =~ "Edit Test rig"

      assert form_live
             |> form("#test_rig-form", test_rig: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#test_rig-form", test_rig: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/test_rigs/#{test_rig}")

      html = render(show_live)
      assert html =~ "Test rig updated successfully"
      assert html =~ "some updated name"
    end
  end
end
