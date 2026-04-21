defmodule HackathonTestRig.Repo.Migrations.CreateTestRigs do
  use Ecto.Migration

  def change do
    create table(:test_rigs) do
      add :name, :string
      add :hostname, :string
      add :location, :string

      timestamps(type: :utc_datetime)
    end
  end
end
