defmodule HackathonTestRig.Orchestrator.Task do
  use Ecto.Schema
  import Ecto.Changeset

  alias HackathonTestRig.Orchestrator.Flow

  @statuses [:pending, :executing, :completed, :failed]

  schema "tasks" do
    embeds_many :flows, Flow, on_replace: :delete
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
    |> cast_embed(:flows, with: &Flow.changeset/2, required: true)
    |> validate_required([:maximum_execution_time, :scheduled_time, :status])
    |> validate_number(:maximum_execution_time, greater_than: 0)
    |> validate_length(:flows, min: 1)
  end
end
