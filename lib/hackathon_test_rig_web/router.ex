defmodule HackathonTestRigWeb.Router do
  use HackathonTestRigWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HackathonTestRigWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HackathonTestRigWeb do
    pipe_through :browser

    live "/", HomeLive, :index

    live "/test_rigs", TestRigLive.Index, :index
    live "/test_rigs/new", TestRigLive.Form, :new
    live "/test_rigs/:id", TestRigLive.Show, :show
    live "/test_rigs/:id/edit", TestRigLive.Form, :edit

    live "/devices", DeviceLive.Index, :index
    live "/devices/new", DeviceLive.Form, :new
    live "/devices/:id", DeviceLive.Show, :show
    live "/devices/:id/edit", DeviceLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", HackathonTestRigWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:hackathon_test_rig, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router
    import Oban.Web.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HackathonTestRigWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      oban_dashboard "/oban"
    end
  end
end
