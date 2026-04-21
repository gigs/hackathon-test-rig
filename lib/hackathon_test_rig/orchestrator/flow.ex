defmodule HackathonTestRig.Orchestrator.Flow do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:pending, :executing, :completed, :failed]

  @primary_key false
  embedded_schema do
    field :device_id, :id
    field :maximum_execution_time, :integer
    field :maestro_flow, :string
    field :maestro_arguments, :map, default: %{}
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :job_id, :integer
  end

  def statuses, do: @statuses

  @doc false
  def changeset(flow, attrs) do
    flow
    |> cast(attrs, [
      :device_id,
      :maximum_execution_time,
      :maestro_flow,
      :maestro_arguments,
      :status,
      :job_id
    ])
    |> validate_required([:device_id, :maximum_execution_time, :maestro_flow, :status])
    |> validate_number(:maximum_execution_time, greater_than: 0)
  end
end
