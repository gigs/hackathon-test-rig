defmodule HackathonTestRig.Repo do
  use Ecto.Repo,
    otp_app: :hackathon_test_rig,
    adapter: Ecto.Adapters.Postgres
end
