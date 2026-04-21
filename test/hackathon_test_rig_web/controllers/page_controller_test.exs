defmodule HackathonTestRigWeb.PageControllerTest do
  use HackathonTestRigWeb.ConnCase

  test "GET / renders the interactive world map", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Test Rig Network"
    assert html =~ ~s(id="world-map")
  end
end
