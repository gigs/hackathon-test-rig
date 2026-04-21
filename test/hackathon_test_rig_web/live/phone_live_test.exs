defmodule HackathonTestRigWeb.PhoneLiveTest do
  use HackathonTestRigWeb.ConnCase

  import Phoenix.LiveViewTest
  import HackathonTestRig.InventoryFixtures

  @invalid_attrs %{name: nil, os_version: nil, type: nil, device_model: nil, test_rig_id: nil}
  defp create_phone(_) do
    phone = phone_fixture()

    %{phone: phone}
  end

  defp create_attrs(test_rig_id) do
    %{
      name: "some name",
      os_version: "some os_version",
      type: :android,
      device_model: "some device_model",
      test_rig_id: test_rig_id
    }
  end

  defp update_attrs(test_rig_id) do
    %{
      name: "some updated name",
      os_version: "some updated os_version",
      type: :ios,
      device_model: "some updated device_model",
      test_rig_id: test_rig_id
    }
  end

  describe "Index" do
    setup [:create_phone]

    test "lists all phones", %{conn: conn, phone: phone} do
      {:ok, _index_live, html} = live(conn, ~p"/phones")

      assert html =~ "Listing Phones"
      assert html =~ phone.name
    end

    test "saves new phone", %{conn: conn} do
      test_rig = test_rig_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/phones")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Phone")
               |> render_click()
               |> follow_redirect(conn, ~p"/phones/new")

      assert render(form_live) =~ "New Phone"

      assert form_live
             |> form("#phone-form", phone: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#phone-form", phone: create_attrs(test_rig.id))
               |> render_submit()
               |> follow_redirect(conn, ~p"/phones")

      html = render(index_live)
      assert html =~ "Phone created successfully"
      assert html =~ "some name"
    end

    test "updates phone in listing", %{conn: conn, phone: phone} do
      {:ok, index_live, _html} = live(conn, ~p"/phones")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#phones-#{phone.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/phones/#{phone}/edit")

      assert render(form_live) =~ "Edit Phone"

      assert form_live
             |> form("#phone-form", phone: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#phone-form", phone: update_attrs(phone.test_rig_id))
               |> render_submit()
               |> follow_redirect(conn, ~p"/phones")

      html = render(index_live)
      assert html =~ "Phone updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes phone in listing", %{conn: conn, phone: phone} do
      {:ok, index_live, _html} = live(conn, ~p"/phones")

      assert index_live |> element("#phones-#{phone.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#phones-#{phone.id}")
    end
  end

  describe "Show" do
    setup [:create_phone]

    test "displays phone", %{conn: conn, phone: phone} do
      {:ok, _show_live, html} = live(conn, ~p"/phones/#{phone}")

      assert html =~ "Show Phone"
      assert html =~ phone.name
    end

    test "updates phone and returns to show", %{conn: conn, phone: phone} do
      {:ok, show_live, _html} = live(conn, ~p"/phones/#{phone}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/phones/#{phone}/edit?return_to=show")

      assert render(form_live) =~ "Edit Phone"

      assert form_live
             |> form("#phone-form", phone: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#phone-form", phone: update_attrs(phone.test_rig_id))
               |> render_submit()
               |> follow_redirect(conn, ~p"/phones/#{phone}")

      html = render(show_live)
      assert html =~ "Phone updated successfully"
      assert html =~ "some updated name"
    end
  end
end
