defmodule HackathonTestRig.Orchestrator.Task do
  use Ecto.Schema
  import Ecto.Changeset

  alias HackathonTestRig.Orchestrator.TaskStep

  @statuses [:pending, :executing, :completed, :failed]

  schema "tasks" do
    has_many :steps, TaskStep, preload_order: [asc: :id], on_replace: :delete
    field :maximum_execution_time, :integer
    field :scheduled_time, :utc_datetime
    field :status, Ecto.Enum, values: @statuses, default: :pending

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:maximum_execution_time, :scheduled_time, :status])
    |> cast_assoc(:steps, with: &TaskStep.changeset/2, required: true)
    |> validate_required([:maximum_execution_time, :scheduled_time, :status])
    |> validate_number(:maximum_execution_time, greater_than: 0)
    |> validate_length(:steps, min: 1)
  end
end
