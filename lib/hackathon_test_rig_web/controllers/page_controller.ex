defmodule HackathonTestRigWeb.PageController do
  use HackathonTestRigWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
