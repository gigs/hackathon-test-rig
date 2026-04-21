defmodule HackathonTestRig.Inventory.TestRig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "test_rigs" do
    field :name, :string
    field :hostname, :string
    field :location, :string

    has_many :phones, HackathonTestRig.Inventory.Phone

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(test_rig, attrs) do
    test_rig
    |> cast(attrs, [:name, :hostname, :location])
    |> validate_required([:name, :hostname, :location])
  end
end
