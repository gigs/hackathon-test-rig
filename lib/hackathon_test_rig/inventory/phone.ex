defmodule HackathonTestRig.Inventory.Phone do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phones" do
    field :name, :string
    field :type, Ecto.Enum, values: [:android, :ios]
    field :device_model, :string
    field :os_version, :string

    belongs_to :test_rig, HackathonTestRig.Inventory.TestRig

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(phone, attrs) do
    phone
    |> cast(attrs, [:name, :type, :device_model, :os_version, :test_rig_id])
    |> validate_required([:name, :type, :device_model, :os_version, :test_rig_id])
    |> assoc_constraint(:test_rig)
  end
end
