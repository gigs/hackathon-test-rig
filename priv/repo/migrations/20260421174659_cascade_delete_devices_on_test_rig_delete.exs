defmodule HackathonTestRig.Repo.Migrations.CascadeDeleteDevicesOnTestRigDelete do
  use Ecto.Migration

  def change do
    drop constraint(:devices, "devices_test_rig_id_fkey")

    alter table(:devices) do
      modify :test_rig_id, references(:test_rigs, on_delete: :delete_all)
    end
  end
end
