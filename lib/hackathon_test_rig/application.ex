defmodule HackathonTestRig.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HackathonTestRigWeb.Telemetry,
      HackathonTestRig.Repo,
      {DNSCluster, query: Application.get_env(:hackathon_test_rig, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HackathonTestRig.PubSub},
      HackathonTestRig.ObanSupervisor,
      # Start a worker by calling: HackathonTestRig.Worker.start_link(arg)
      # {HackathonTestRig.Worker, arg},
      # Start to serve requests, typically the last entry
      HackathonTestRigWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HackathonTestRig.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HackathonTestRigWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
