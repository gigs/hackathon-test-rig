defmodule HackathonTestRig.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string
      add :type, :string
      add :device_model, :string
      add :os_version, :string
      add :test_rig_id, references(:test_rigs, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:devices, [:test_rig_id])
  end
end
