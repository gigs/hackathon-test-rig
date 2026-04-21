defmodule HackathonTestRig.Repo.Migrations.CreateTaskSteps do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      remove :flows, {:array, :map}, null: false, default: []
    end

    create table(:task_steps) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :type, :string, null: false, default: "flow"
      add :device_id, references(:devices, on_delete: :nilify_all)
      add :maximum_execution_time, :integer, null: false
      add :status, :string, null: false, default: "pending"
      add :job_id, :integer
      add :data, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:task_steps, [:task_id])
    create index(:task_steps, [:device_id])
    create index(:task_steps, [:status])
  end
end
