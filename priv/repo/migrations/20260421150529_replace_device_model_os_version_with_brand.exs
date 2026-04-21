defmodule HackathonTestRig.Repo.Migrations.ReplaceDeviceModelOsVersionWithBrand do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      remove :device_model, :string
      remove :os_version, :string
      add :brand, :string
    end
  end
end
