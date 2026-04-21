defmodule HackathonTestRig.Inventory.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field :name, :string
    field :type, Ecto.Enum, values: [:smartphone, :tablet]
    field :brand, :string

    belongs_to :test_rig, HackathonTestRig.Inventory.TestRig

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :type, :brand, :test_rig_id])
    |> validate_required([:name, :type, :brand, :test_rig_id])
    |> assoc_constraint(:test_rig)
  end

  @doc """
  Returns the Oban queue atom dedicated to this device.
  """
  def queue_name(%__MODULE__{name: name}), do: queue_name(name)
  def queue_name(name) when is_binary(name), do: String.to_atom("device:" <> name)

  @doc """
  Returns the maestro platform string for this device.

  Apple-branded devices run on iOS; everything else is treated as Android.
  """
  def platform(%__MODULE__{brand: brand}), do: platform_for_brand(brand)

  defp platform_for_brand(brand) when is_binary(brand) do
    case String.downcase(brand) do
      "apple" -> "ios"
      _ -> "android"
    end
  end
end
