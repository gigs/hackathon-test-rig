defmodule HackathonTestRig.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :flows, {:array, :map}, null: false, default: []
      add :maximum_execution_time, :integer, null: false
      add :scheduled_time, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:status])
    create index(:tasks, [:scheduled_time])
  end
end
