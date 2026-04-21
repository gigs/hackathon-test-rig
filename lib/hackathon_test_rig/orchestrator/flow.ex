defmodule HackathonTestRig.Orchestrator.Flow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :device_id, :id
    field :maximum_execution_time, :integer
    field :maestro_flow, :string
    field :maestro_arguments, :map, default: %{}
  end

  @doc false
  def changeset(flow, attrs) do
    flow
    |> cast(attrs, [:device_id, :maximum_execution_time, :maestro_flow, :maestro_arguments])
    |> validate_required([:device_id, :maximum_execution_time, :maestro_flow])
    |> validate_number(:maximum_execution_time, greater_than: 0)
  end
end
