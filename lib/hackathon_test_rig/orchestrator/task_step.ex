defmodule HackathonTestRig.Orchestrator.TaskStep do
  use Ecto.Schema
  import Ecto.Changeset

  alias HackathonTestRig.Orchestrator.Task

  @statuses [:pending, :executing, :completed, :failed]
  @types [:flow, :reservation]

  schema "task_steps" do
    belongs_to :task, Task
    field :type, Ecto.Enum, values: @types, default: :flow
    field :device_id, :id
    field :maximum_execution_time, :integer
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :job_id, :integer
    field :data, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def types, do: @types

  @doc false
  def changeset(step, attrs) do
    step
    |> cast(attrs, [
      :type,
      :device_id,
      :maximum_execution_time,
      :status,
      :job_id,
      :data
    ])
    |> validate_required([:type, :device_id, :maximum_execution_time, :status])
    |> validate_number(:maximum_execution_time, greater_than: 0)
  end
end
